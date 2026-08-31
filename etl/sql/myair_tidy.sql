-- ============================================================================
-- myair_tidy.sql
--
-- Source tables (read only):
--   myair(deviceId, firmware, event_ts DATETIME, created_at TIMESTAMP,
--         pm1, pm25, pm10, pc03, pc05, pc1, pc25, pc5, pc10,
--         temperature, humidity, pressure, sound, uvb, light)
--   user_myair(deviceId, userId)
--
-- Managed objects:
--   myair_tidy
--   etl_myair_tidy()
--
-- Usage:
--   CALL etl_myair_tidy();
--
-- An empty myair_tidy triggers a full build, committed one participant at a
-- time to keep InnoDB lock usage bounded. Otherwise the procedure finds raw
-- rows whose created_at is greater than MAX(myair_tidy.created_at), then fully
-- rebuilds their event dates in one incremental transaction.
-- ============================================================================


CREATE TABLE IF NOT EXISTS myair_tidy (            -- Preserve a compatible existing table.
  userId      BIGINT       NOT NULL,               -- Pseudonymous participant identifier.
  minute_ts   DATETIME(6)  NOT NULL,               -- UTC event minute, with seconds set to zero.
  bucket_5min DATETIME(6)  NOT NULL,               -- Start of the containing UTC five-minute bucket.
  event_ts    DATETIME(6)  NOT NULL,               -- Original event timestamp from raw MyAir.
  created_at  DATETIME(6)  NOT NULL,               -- Raw ingestion time, read and stored in UTC.
  deviceId    VARCHAR(128) NOT NULL,               -- Source device, retained as provenance.
  firmware    VARCHAR(128) NOT NULL,               -- Source firmware, retained as provenance.

  pm1         DOUBLE NULL,                         -- Particulate mass in micrograms per cubic metre.
  pm25        DOUBLE NULL,                         -- Particulate mass in micrograms per cubic metre.
  pm10        DOUBLE NULL,                         -- Particulate mass in micrograms per cubic metre.
  pc03        DOUBLE NULL,                         -- Particle count; historical unit is count/dL.
  pc05        DOUBLE NULL,                         -- Particle count; historical unit is count/dL.
  pc1         DOUBLE NULL,                         -- Particle count; historical unit is count/dL.
  pc25        DOUBLE NULL,                         -- Particle count; historical unit is count/dL.
  pc5         DOUBLE NULL,                         -- Particle count; historical unit is count/dL.
  pc10        DOUBLE NULL,                         -- Particle count; historical unit is count/dL.
  temperature DOUBLE NULL,                         -- Preserved as recorded; range and unit unresolved.
  humidity    DOUBLE NULL,                         -- Relative humidity in percent.
  pressure    DOUBLE NULL,                         -- Atmospheric pressure in hPa.
  sound       DOUBLE NULL,                         -- Sound measurement on the recorded sensor scale.
  uvb         DOUBLE NULL,                         -- UVB measurement on the recorded sensor scale.
  light       DOUBLE NULL,                         -- Light measurement on the recorded sensor scale.

  PRIMARY KEY (userId, minute_ts),                 -- Enforce one row per participant-minute.
  INDEX idx_myair_tidy_user_bucket (userId, bucket_5min), -- Support participant time-series queries.
  INDEX idx_myair_tidy_bucket (bucket_5min),       -- Support shared five-minute bucket queries.
  INDEX idx_myair_tidy_created_at (created_at),    -- Speed up the incremental watermark lookup.

  CONSTRAINT chk_myair_tidy_pm
    CHECK (                                        -- Permit valid mass values or cleaned NULLs.
      (pm1 IS NULL OR pm1 BETWEEN 0 AND 65534)
      AND (pm25 IS NULL OR pm25 BETWEEN 0 AND 65534)
      AND (pm10 IS NULL OR pm10 BETWEEN 0 AND 65534)
    ),
  CONSTRAINT chk_myair_tidy_pc
    CHECK (                                        -- Permit valid count values or cleaned NULLs.
      (pc03 IS NULL OR pc03 BETWEEN 0 AND 65534)
      AND (pc05 IS NULL OR pc05 BETWEEN 0 AND 65534)
      AND (pc1 IS NULL OR pc1 BETWEEN 0 AND 65534)
      AND (pc25 IS NULL OR pc25 BETWEEN 0 AND 65534)
      AND (pc5 IS NULL OR pc5 BETWEEN 0 AND 65534)
      AND (pc10 IS NULL OR pc10 BETWEEN 0 AND 65534)
    ),
  CONSTRAINT chk_myair_tidy_humidity
    CHECK (humidity IS NULL OR humidity BETWEEN 0 AND 100), -- Enforce percent bounds.
  CONSTRAINT chk_myair_tidy_pressure
    CHECK (pressure IS NULL OR pressure BETWEEN 300 AND 1100), -- Keep the historical hPa range.
  CONSTRAINT chk_myair_tidy_sound
    CHECK (sound IS NULL OR sound BETWEEN 0 AND 200), -- Keep the historical technical range.
  CONSTRAINT chk_myair_tidy_uvb
    CHECK (uvb IS NULL OR uvb BETWEEN 0 AND 6552),  -- Exclude the observed 6553 error code.
  CONSTRAINT chk_myair_tidy_light
    CHECK (light IS NULL OR light >= 0)             -- Negative light readings are invalid.
) ENGINE = InnoDB;                                 -- InnoDB makes DELETE and INSERT transactional.


-- Use // so semicolons inside the procedure do not end CREATE PROCEDURE.
DELIMITER //


CREATE OR REPLACE PROCEDURE etl_myair_tidy()       -- Replace the routine, not the output table.
SQL SECURITY INVOKER                               -- Use the privileges of the account running CALL.
MODIFIES SQL DATA                                  -- Declare that the procedure writes database data.
main: BEGIN                                        -- Open a named procedure block.
  DECLARE v_started_at DATETIME(6);                -- UTC procedure start time.
  DECLARE v_finished_at DATETIME(6);               -- UTC procedure finish time.
  DECLARE v_previous_created_at DATETIME(6) DEFAULT NULL; -- Current tidy ingestion watermark.
  DECLARE v_raw_max_created_at DATETIME(6) DEFAULT NULL;  -- Raw upper cutoff for this run.
  DECLARE v_old_time_zone VARCHAR(64);             -- Session timezone to restore before returning.
  DECLARE v_is_full BOOLEAN DEFAULT FALSE;         -- TRUE only when myair_tidy is empty.
  DECLARE v_user_id BIGINT DEFAULT NULL;           -- Participant currently processed by the cursor.
  DECLARE v_cursor_done BOOLEAN DEFAULT FALSE;     -- TRUE after the cursor has no more participants.

  DECLARE v_affected_days BIGINT UNSIGNED DEFAULT 0; -- Number of event dates rebuilt.
  DECLARE v_source_rows BIGINT UNSIGNED DEFAULT 0;   -- Raw rows in the dates being rebuilt.
  DECLARE v_deleted_rows BIGINT UNSIGNED DEFAULT 0;  -- Tidy rows removed before rebuilding.
  DECLARE v_inserted_rows BIGINT UNSIGNED DEFAULT 0; -- Clean rows inserted by this run.
  DECLARE v_batch_inserted_rows BIGINT UNSIGNED DEFAULT 0; -- Rows inserted for one participant.
  DECLARE v_total_rows BIGINT UNSIGNED DEFAULT 0;    -- Final myair_tidy row count.

  DECLARE cur_myair_users CURSOR FOR                -- Read the participants selected for this run.
    SELECT userId
    FROM tmp_myair_run_users
    ORDER BY userId;

  DECLARE CONTINUE HANDLER FOR NOT FOUND            -- FETCH uses NOT FOUND at the end of the cursor.
    SET v_cursor_done = TRUE;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION             -- Catch any SQL error raised below.
  BEGIN
    ROLLBACK;                                       -- Undo the current participant or incremental run.

    IF v_is_full THEN                               -- Earlier participants may already be committed.
      TRUNCATE TABLE myair_tidy;                    -- Restore the empty state required to retry full.
    END IF;

    IF v_old_time_zone IS NOT NULL THEN             -- Restore it only after it was saved.
      SET SESSION time_zone = v_old_time_zone;      -- Preserve the caller's later query behaviour.
    END IF;

    RESIGNAL;                                       -- Return the original error to the caller.
  END;

  SET v_old_time_zone = @@SESSION.time_zone;        -- Remember the caller's current timezone.
  -- myair.created_at is expected to be TIMESTAMP; normalize reads to UTC.
  SET SESSION time_zone = '+00:00';                 -- Make TIMESTAMP reads explicitly UTC.
  SET v_started_at = UTC_TIMESTAMP(6);              -- Record when this run started.

  SELECT MAX(t.created_at)
  INTO v_previous_created_at                        -- Store the current tidy watermark.
  FROM myair_tidy AS t;                             -- NULL means that myair_tidy is empty.

  SELECT MAX(m.created_at)
  INTO v_raw_max_created_at                         -- Freeze the raw upper cutoff for this run.
  FROM myair AS m;                                  -- Later raw uploads wait for the next run.

  SET v_is_full = (v_previous_created_at IS NULL);  -- Select full or incremental mode automatically.

  DROP TEMPORARY TABLE IF EXISTS tmp_myair_days;    -- Clear leftovers in the same DB session.
  CREATE TEMPORARY TABLE tmp_myair_days (           -- Visible only to this connection.
    event_date DATE NOT NULL,                       -- Calendar date derived from event_ts.
    PRIMARY KEY (event_date)                        -- Store each affected date once.
  ) ENGINE = InnoDB;                                -- Keep temporary changes transactional.

  DROP TEMPORARY TABLE IF EXISTS tmp_myair_device_map; -- Clear a previous call in this session.
  CREATE TEMPORARY TABLE tmp_myair_device_map (     -- Keep only unambiguous device assignments.
    deviceId VARCHAR(100) NOT NULL,                 -- Raw device identifier used by the source index.
    userId BIGINT NOT NULL,                         -- Unique participant assigned to the device.
    PRIMARY KEY (deviceId),                         -- Store one resolved mapping per device.
    INDEX idx_tmp_myair_device_user (userId)        -- Find all devices owned by one participant.
  ) ENGINE = InnoDB;

  INSERT INTO tmp_myair_device_map (deviceId, userId)
  SELECT
    um.deviceId,
    MIN(um.userId) AS userId                        -- Safe because HAVING requires one user.
  FROM user_myair AS um
  WHERE um.deviceId IS NOT NULL                    -- A missing device cannot be joined.
    AND TRIM(um.deviceId) <> ''                    -- Ignore blank device identifiers.
    AND um.userId IS NOT NULL                      -- A missing participant is not a valid mapping.
  GROUP BY um.deviceId
  HAVING COUNT(DISTINCT um.userId) = 1;            -- Exclude devices assigned to several users.

  IF v_is_full THEN                                 -- Empty tidy: process all visible dates.
    INSERT INTO tmp_myair_days (event_date)         -- Build the complete list of event dates.
    SELECT DISTINCT DATE(m.event_ts)
    FROM myair AS m
    WHERE m.event_ts IS NOT NULL                    -- A missing event time has no rebuild date.
      AND (
        m.created_at <= v_raw_max_created_at        -- Stay inside this run's frozen cutoff.
        OR m.created_at IS NULL                     -- Include its date in full diagnostics.
      );
  ELSE                                              -- Populated tidy: inspect only newer uploads.
    INSERT INTO tmp_myair_days (event_date)         -- Collect dates touched by new raw rows.
    SELECT DISTINCT DATE(m.event_ts)
    FROM myair AS m
    WHERE m.event_ts IS NOT NULL                    -- Ignore rows without an event date.
      AND m.created_at > v_previous_created_at      -- No fixed lookback window is applied.
      AND m.created_at <= v_raw_max_created_at;     -- Keep this run internally consistent.
  END IF;

  SELECT COUNT(*)
  INTO v_affected_days                              -- Save the number of dates to rebuild.
  FROM tmp_myair_days;

  SELECT COUNT(*)
  INTO v_source_rows                                -- Count all raw rows in affected dates.
  FROM myair AS m
  INNER JOIN tmp_myair_days AS d
    ON d.event_date = DATE(m.event_ts)              -- Rebuild complete dates, including late uploads.
  WHERE m.created_at <= v_raw_max_created_at        -- Use the same cutoff as the transformation.
     OR m.created_at IS NULL;                       -- Count rows later rejected for missing upload time.

  DROP TEMPORARY TABLE IF EXISTS tmp_myair_run_users; -- Clear a previous call in this session.
  CREATE TEMPORARY TABLE tmp_myair_run_users (      -- Participants that must be processed now.
    userId BIGINT NOT NULL,
    PRIMARY KEY (userId)                            -- Process each participant only once.
  ) ENGINE = InnoDB;

  IF v_is_full THEN                                 -- Full mode processes every resolved participant.
    INSERT INTO tmp_myair_run_users (userId)
    SELECT DISTINCT dm.userId
    FROM tmp_myair_device_map AS dm;
  ELSE                                              -- Incremental mode needs users in affected dates.
    INSERT INTO tmp_myair_run_users (userId)
    SELECT DISTINCT dm.userId
    FROM tmp_myair_device_map AS dm
    INNER JOIN myair AS m
      ON m.deviceId = dm.deviceId                  -- Use the existing raw device index.
    INNER JOIN tmp_myair_days AS d
      ON d.event_date = DATE(m.event_ts)            -- Include complete affected event dates.
    WHERE m.created_at <= v_raw_max_created_at      -- Apply the frozen cutoff to this user list.
       OR m.created_at IS NULL;
  END IF;

  IF NOT v_is_full THEN                             -- Keep incremental replacement all-or-nothing.
    START TRANSACTION;

    DELETE t
    FROM myair_tidy AS t
    INNER JOIN tmp_myair_days AS d
      ON d.event_date = DATE(t.event_ts);           -- Remove prior results for rebuilt dates.
    SET v_deleted_rows = ROW_COUNT();               -- Save the incremental deletion count.
  END IF;

  SET v_cursor_done = FALSE;                        -- Prepare to read the participant cursor.
  OPEN cur_myair_users;

  participant_loop: LOOP
    FETCH cur_myair_users INTO v_user_id;           -- Select one participant for this batch.

    IF v_cursor_done THEN                           -- FETCH sets this after the final participant.
      LEAVE participant_loop;
    END IF;

    IF v_is_full THEN                               -- Bound full-build locks to one participant.
      START TRANSACTION;
    END IF;

    INSERT INTO myair_tidy (                        -- Map final values to explicit output columns.
      userId,
      minute_ts,
      bucket_5min,
      event_ts,
      created_at,
      deviceId,
      firmware,
      pm1,
      pm25,
      pm10,
      pc03,
      pc05,
      pc1,
      pc25,
      pc5,
      pc10,
      temperature,
      humidity,
      pressure,
      sound,
      uvb,
      light
    )
    WITH
    required_rows AS (                             -- Step 1: select one participant's valid devices.
      SELECT
        dm.userId,
        m.deviceId,
        m.firmware,
        m.event_ts,
        m.created_at,
        TIMESTAMP(
          DATE(m.event_ts),
          MAKETIME(HOUR(m.event_ts), MINUTE(m.event_ts), 0)
        ) AS minute_ts,                             -- Beginning of the raw event minute.
        m.pm1,
        m.pm25,
        m.pm10,
        m.pc03,
        m.pc05,
        m.pc1,
        m.pc25,
        m.pc5,
        m.pc10,
        m.temperature,
        m.humidity,
        m.pressure,
        m.sound,
        m.uvb,
        m.light,
        MIN(m.created_at) OVER (
          PARTITION BY m.deviceId, m.firmware, m.event_ts
        ) AS first_created_at                       -- Earliest upload of the exact device event.
      FROM tmp_myair_device_map AS dm
      INNER JOIN myair AS m
        ON m.deviceId = dm.deviceId                -- Use the raw index whose first column is deviceId.
      INNER JOIN tmp_myair_days AS d
        ON d.event_date = DATE(m.event_ts)          -- Read only dates selected for rebuilding.
      WHERE dm.userId = v_user_id                  -- Keep this statement participant-sized.
        AND m.firmware IS NOT NULL                  -- Retained as source provenance.
        AND TRIM(m.firmware) <> ''                  -- Reject blank firmware values.
        AND m.event_ts IS NOT NULL                  -- Required to construct the analytical minute.
        AND m.created_at IS NOT NULL                -- Required by incremental processing.
        AND m.created_at <= v_raw_max_created_at    -- Apply this run's frozen upper cutoff.
    ),

    earliest_payloads AS (                         -- Step 2: keep the earliest upload only.
      SELECT
        userId,
        deviceId,
        firmware,
        event_ts,
        created_at,
        minute_ts,
        pm1,
        pm25,
        pm10,
        pc03,
        pc05,
        pc1,
        pc25,
        pc5,
        pc10,
        temperature,
        humidity,
        pressure,
        sound,
        uvb,
        light
      FROM required_rows
      WHERE created_at = first_created_at           -- Ignore later copies of the same event.
      GROUP BY                                      -- Collapse completely equal earliest copies.
        userId,
        deviceId,
        firmware,
        event_ts,
        created_at,
        minute_ts,
        pm1,
        pm25,
        pm10,
        pc03,
        pc05,
        pc1,
        pc25,
        pc5,
        pc10,
        temperature,
        humidity,
        pressure,
        sound,
        uvb,
        light
    ),

    event_checked AS (                             -- Step 3: detect conflicting earliest payloads.
      SELECT
        p.*,
        COUNT(*) OVER (
          PARTITION BY p.deviceId, p.firmware, p.event_ts
        ) AS payload_n                             -- More than one means values disagree.
      FROM earliest_payloads AS p
    ),

    device_minute_checked AS (                     -- Step 4: detect multiple events in a minute.
      SELECT
        e.*,
        COUNT(*) OVER (
          PARTITION BY e.deviceId, e.firmware, e.minute_ts
        ) AS event_n                               -- More than one makes the device-minute ambiguous.
      FROM event_checked AS e
      WHERE e.payload_n = 1                        -- Remove conflicting exact events first.
    ),

    cleaned_values AS (                            -- Step 5: clean each measurement independently.
      SELECT
        userId,
        deviceId,
        firmware,
        event_ts,
        created_at,
        minute_ts,
        CASE WHEN pm1 BETWEEN 0 AND 65534 THEN pm1 ELSE NULL END AS pm1,
        CASE WHEN pm25 BETWEEN 0 AND 65534 THEN pm25 ELSE NULL END AS pm25,
        CASE WHEN pm10 BETWEEN 0 AND 65534 THEN pm10 ELSE NULL END AS pm10,
        CASE WHEN pc03 BETWEEN 0 AND 65534 THEN pc03 ELSE NULL END AS pc03,
        CASE WHEN pc05 BETWEEN 0 AND 65534 THEN pc05 ELSE NULL END AS pc05,
        CASE WHEN pc1 BETWEEN 0 AND 65534 THEN pc1 ELSE NULL END AS pc1,
        CASE WHEN pc25 BETWEEN 0 AND 65534 THEN pc25 ELSE NULL END AS pc25,
        CASE WHEN pc5 BETWEEN 0 AND 65534 THEN pc5 ELSE NULL END AS pc5,
        CASE WHEN pc10 BETWEEN 0 AND 65534 THEN pc10 ELSE NULL END AS pc10,
        temperature,                               -- Preserve until a defensible range is known.
        CASE WHEN humidity BETWEEN 0 AND 100 THEN humidity ELSE NULL END AS humidity,
        CASE WHEN pressure BETWEEN 300 AND 1100 THEN pressure ELSE NULL END AS pressure,
        CASE WHEN sound BETWEEN 0 AND 200 THEN sound ELSE NULL END AS sound,
        CASE WHEN uvb BETWEEN 0 AND 6552 THEN uvb ELSE NULL END AS uvb,
        CASE WHEN light >= 0 THEN light ELSE NULL END AS light
      FROM device_minute_checked
      WHERE event_n = 1                            -- Keep one unambiguous event per device-minute.
    ),

    usable_rows AS (                               -- Step 6: remove rows with no usable measurement.
      SELECT
        *
      FROM cleaned_values
      WHERE pm1 IS NOT NULL
         OR pm25 IS NOT NULL
         OR pm10 IS NOT NULL
         OR pc03 IS NOT NULL
         OR pc05 IS NOT NULL
         OR pc1 IS NOT NULL
         OR pc25 IS NOT NULL
         OR pc5 IS NOT NULL
         OR pc10 IS NOT NULL
         OR temperature IS NOT NULL
         OR humidity IS NOT NULL
         OR pressure IS NOT NULL
         OR sound IS NOT NULL
         OR uvb IS NOT NULL
         OR light IS NOT NULL
    ),

    participant_minute_checked AS (                -- Step 7: enforce participant-minute uniqueness.
      SELECT
        p.*,
        COUNT(*) OVER (
          PARTITION BY p.userId, p.minute_ts
        ) AS candidate_n                           -- Detect multiple devices or firmware versions.
      FROM usable_rows AS p
    )

    SELECT
      userId,
      minute_ts,
      minute_ts - INTERVAL (MINUTE(minute_ts) MOD 5) MINUTE, -- Floor to a five-minute boundary.
      event_ts,
      created_at,
      deviceId,
      firmware,
      pm1,
      pm25,
      pm10,
      pc03,
      pc05,
      pc1,
      pc25,
      pc5,
      pc10,
      temperature,
      humidity,
      pressure,
      sound,
      uvb,
      light
    FROM participant_minute_checked
    WHERE candidate_n = 1;                         -- Never choose arbitrarily between candidates.

    SET v_batch_inserted_rows = ROW_COUNT();       -- Capture this participant's inserted rows.
    SET v_inserted_rows =                          -- Accumulate the complete run's insert count.
      v_inserted_rows + v_batch_inserted_rows;

    IF v_is_full THEN                              -- Release this participant's InnoDB locks now.
      COMMIT;
    END IF;
  END LOOP;

  CLOSE cur_myair_users;

  IF NOT v_is_full THEN                            -- Finish the one incremental transaction.
    COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_total_rows                                -- Count the complete final tidy table.
  FROM myair_tidy;

  SET v_finished_at = UTC_TIMESTAMP(6);            -- Record successful completion time.
  SET SESSION time_zone = v_old_time_zone;         -- Restore the caller's original timezone.

  SELECT
    IF(v_is_full, 'full', 'incremental') AS run_mode, -- Report the selected refresh mode.
    v_started_at AS started_at,                    -- UTC start of the procedure call.
    v_finished_at AS finished_at,                  -- UTC end of the successful procedure call.
    v_previous_created_at AS previous_created_at,  -- Watermark found before this run.
    v_raw_max_created_at AS raw_max_created_at,    -- Raw upper cutoff used by this run.
    v_affected_days AS affected_days,              -- Number of complete event dates rebuilt.
    v_source_rows AS source_rows,                  -- Raw rows seen in those event dates.
    v_deleted_rows AS deleted_tidy_rows,           -- Existing tidy rows removed by this run.
    v_inserted_rows AS inserted_tidy_rows,         -- Clean tidy rows inserted by this run.
    v_total_rows AS total_tidy_rows;               -- Return one non-persistent summary row.
END//


-- Restore the normal client delimiter for subsequent SQL statements.
DELIMITER ;
