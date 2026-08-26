-- ============================================================================
-- smartwatchhigh_tidy.sql
--
-- Source tables (read only):
--   smartwatchhigh(deviceId, firmware, event_ts DATETIME,
--                  created_at TIMESTAMP, heartrate, oxygens,
--                  breathrate, sleeprate)
--   user_smartwatchhigh(deviceId, userId)
--
-- Managed objects:
--   smartwatchhigh_tidy
--   etl_smartwatchhigh_tidy()
--
-- Usage:
--   CALL etl_smartwatchhigh_tidy();
--
-- An empty smartwatchhigh_tidy triggers a full build, committed one participant
-- at a time. Otherwise the procedure finds raw rows whose created_at is greater
-- than MAX(smartwatchhigh_tidy.created_at) and rebuilds their complete
-- participant-minutes in one incremental transaction.
-- ============================================================================


CREATE TABLE IF NOT EXISTS smartwatchhigh_tidy (  -- Preserve a compatible existing table.
  userId      BIGINT       NOT NULL,               -- Pseudonymous participant identifier.
  minute_ts   DATETIME(6)  NOT NULL,               -- UTC event minute, with seconds set to zero.
  bucket_5min DATETIME(6)  NOT NULL,               -- Start of the containing UTC five-minute bucket.
  event_ts    DATETIME(6)  NOT NULL,               -- Original event timestamp from raw smartwatch.
  created_at  DATETIME(6)  NOT NULL,               -- Raw ingestion time, read and stored in UTC.
  deviceId    VARCHAR(128) NOT NULL,               -- Source device, retained as provenance.
  firmware    VARCHAR(128) NOT NULL,               -- Source firmware, retained as provenance.

  heartrate  INT UNSIGNED      NULL,               -- Positive heart rate in beats per minute.
  oxygens    TINYINT UNSIGNED  NULL,               -- Oxygen saturation from 1 through 100 percent.
  breathrate TINYINT UNSIGNED  NULL,               -- Breathing rate from 1 through 100 breaths/minute.
  sleeprate  TINYINT UNSIGNED  NULL,               -- Raw sleep-state code from 0 through 4.

  PRIMARY KEY (userId, minute_ts),                 -- Enforce one row per participant-minute.
  INDEX idx_smartwatchhigh_tidy_user_bucket (userId, bucket_5min), -- Participant time series.
  INDEX idx_smartwatchhigh_tidy_bucket (bucket_5min), -- Shared five-minute bucket queries.
  INDEX idx_smartwatchhigh_tidy_created_at (created_at), -- Incremental watermark lookup.

  CONSTRAINT chk_smartwatchhigh_tidy_heartrate
    CHECK (heartrate IS NULL OR heartrate > 0),    -- Zero is the raw missing-value code.
  CONSTRAINT chk_smartwatchhigh_tidy_oxygens
    CHECK (oxygens IS NULL OR oxygens BETWEEN 1 AND 100), -- Percent technical bounds.
  CONSTRAINT chk_smartwatchhigh_tidy_breathrate
    CHECK (breathrate IS NULL OR breathrate BETWEEN 1 AND 100), -- Exclude -1, 0 and 255.
  CONSTRAINT chk_smartwatchhigh_tidy_sleeprate
    CHECK (sleeprate IS NULL OR sleeprate BETWEEN 0 AND 4) -- Keep zero; only -1 is technical missingness.
) ENGINE = InnoDB;                                 -- Participant batches and increments are transactional.


-- Use // so semicolons inside the procedure do not end CREATE PROCEDURE.
DELIMITER //


CREATE OR REPLACE PROCEDURE etl_smartwatchhigh_tidy() -- Replace the routine, not the output table.
SQL SECURITY INVOKER                               -- Use the privileges of the account running CALL.
MODIFIES SQL DATA                                  -- Declare that the procedure writes database data.
main: BEGIN                                        -- Open a named procedure block.
  DECLARE v_started_at DATETIME(6);                -- UTC procedure start time.
  DECLARE v_finished_at DATETIME(6);               -- UTC procedure finish time.
  DECLARE v_previous_created_at DATETIME(6) DEFAULT NULL; -- Current tidy ingestion watermark.
  DECLARE v_raw_max_created_at DATETIME(6) DEFAULT NULL;  -- Frozen raw cutoff for this run.
  DECLARE v_old_time_zone VARCHAR(64);             -- Session timezone to restore before returning.
  DECLARE v_is_full BOOLEAN DEFAULT FALSE;         -- TRUE only when smartwatchhigh_tidy is empty.
  DECLARE v_user_id BIGINT DEFAULT NULL;           -- Participant currently processed by the cursor.
  DECLARE v_cursor_done BOOLEAN DEFAULT FALSE;     -- TRUE after the cursor has no more participants.

  DECLARE v_affected_days BIGINT UNSIGNED DEFAULT 0; -- Number of event dates represented by the scope.
  DECLARE v_source_rows BIGINT UNSIGNED DEFAULT 0;   -- Raw rows read for the selected scope.
  DECLARE v_deleted_rows BIGINT UNSIGNED DEFAULT 0;  -- Tidy rows removed before rebuilding.
  DECLARE v_inserted_rows BIGINT UNSIGNED DEFAULT 0; -- Clean rows inserted by this run.
  DECLARE v_batch_inserted_rows BIGINT UNSIGNED DEFAULT 0; -- Rows inserted for one participant.
  DECLARE v_total_rows BIGINT UNSIGNED DEFAULT 0;    -- Final smartwatchhigh_tidy row count.

  DECLARE cur_smartwatchhigh_users CURSOR FOR      -- Read the participants selected for this run.
    SELECT userId
    FROM tmp_smartwatchhigh_run_users
    ORDER BY userId;

  DECLARE CONTINUE HANDLER FOR NOT FOUND           -- FETCH raises NOT FOUND after the final row.
    SET v_cursor_done = TRUE;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION            -- Catch any SQL error raised below.
  BEGIN
    ROLLBACK;                                      -- Undo the current participant or full increment.

    IF v_is_full THEN                              -- Earlier full participants may be committed.
      TRUNCATE TABLE smartwatchhigh_tidy;          -- Restore the empty state required for a retry.
    END IF;

    IF v_old_time_zone IS NOT NULL THEN            -- Restore it only after it was saved.
      SET SESSION time_zone = v_old_time_zone;     -- Preserve the caller's later query behaviour.
    END IF;

    RESIGNAL;                                      -- Return the original error to the caller.
  END;

  SET v_old_time_zone = @@SESSION.time_zone;       -- Remember the caller's current timezone.
  -- smartwatchhigh.created_at is expected to be TIMESTAMP; normalize reads to UTC.
  SET SESSION time_zone = '+00:00';                -- Make TIMESTAMP reads explicitly UTC.
  SET v_started_at = UTC_TIMESTAMP(6);             -- Record when this run started.

  SELECT MAX(t.created_at)
  INTO v_previous_created_at                       -- Store the current tidy watermark.
  FROM smartwatchhigh_tidy AS t;                   -- NULL means that the tidy table is empty.

  SELECT MAX(s.created_at)
  INTO v_raw_max_created_at                        -- Freeze the raw upper cutoff for this run.
  FROM smartwatchhigh AS s;                        -- Later uploads wait for the next call.

  SET v_is_full = (v_previous_created_at IS NULL); -- Select full or incremental mode automatically.

  IF v_raw_max_created_at IS NULL THEN             -- An empty raw source is not a successful run.
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'smartwatchhigh has no usable created_at watermark';
  END IF;

  DROP TEMPORARY TABLE IF EXISTS tmp_smartwatchhigh_device_map; -- Clear this session's prior helper.
  CREATE TEMPORARY TABLE tmp_smartwatchhigh_device_map (
    deviceId VARCHAR(100) NOT NULL,                -- Raw device identifier used for source lookup.
    userId BIGINT NOT NULL,                        -- Unique participant assigned to the device.
    PRIMARY KEY (deviceId),                        -- Store one resolved mapping per device.
    INDEX idx_tmp_smartwatchhigh_device_user (userId) -- Find all devices assigned to one participant.
  ) ENGINE = InnoDB;

  INSERT INTO tmp_smartwatchhigh_device_map (deviceId, userId)
  SELECT
    um.deviceId,
    MIN(um.userId) AS userId                       -- Safe because HAVING requires one user.
  FROM user_smartwatchhigh AS um
  WHERE um.deviceId IS NOT NULL                   -- A missing device cannot be joined.
    AND TRIM(um.deviceId) <> ''                   -- Ignore blank identifiers.
    AND um.userId IS NOT NULL                     -- A missing participant is not a valid mapping.
  GROUP BY um.deviceId
  HAVING COUNT(DISTINCT um.userId) = 1;           -- Exclude devices assigned to several users.

  DROP TEMPORARY TABLE IF EXISTS tmp_smartwatchhigh_minutes; -- Clear this session's prior helper.
  CREATE TEMPORARY TABLE tmp_smartwatchhigh_minutes (
    userId BIGINT NOT NULL,                        -- Participant affected by a newer raw upload.
    minute_ts DATETIME(6) NOT NULL,                -- Complete participant-minute to rebuild.
    PRIMARY KEY (userId, minute_ts)                -- Store each affected analytical key once.
  ) ENGINE = InnoDB;

  IF NOT v_is_full THEN                            -- A full build reads every visible raw minute.
    INSERT INTO tmp_smartwatchhigh_minutes (userId, minute_ts)
    SELECT DISTINCT
      dm.userId,
      TIMESTAMP(
        DATE(s.event_ts),
        MAKETIME(HOUR(s.event_ts), MINUTE(s.event_ts), 0)
      ) AS minute_ts
    FROM tmp_smartwatchhigh_device_map AS dm
    INNER JOIN smartwatchhigh AS s
      ON s.deviceId = dm.deviceId                 -- Use the device-led raw lookup when available.
    WHERE s.firmware IS NOT NULL                  -- Required by the exact-event key.
      AND TRIM(s.firmware) <> ''                  -- Exclude missing firmware uploads.
      AND s.event_ts IS NOT NULL                  -- Required to construct the participant-minute.
      AND s.created_at > v_previous_created_at    -- Select only uploads not yet represented.
      AND s.created_at <= v_raw_max_created_at;   -- Keep the run inside its frozen cutoff.
  END IF;

  DROP TEMPORARY TABLE IF EXISTS tmp_smartwatchhigh_days; -- Hold aggregate time-partition diagnostics.
  CREATE TEMPORARY TABLE tmp_smartwatchhigh_days (
    event_date DATE NOT NULL,
    PRIMARY KEY (event_date)                       -- Count each represented event date once.
  ) ENGINE = InnoDB;

  IF v_is_full THEN                                -- Full mode reports all visible event dates.
    INSERT INTO tmp_smartwatchhigh_days (event_date)
    SELECT DISTINCT DATE(s.event_ts)
    FROM smartwatchhigh AS s
    WHERE s.event_ts IS NOT NULL
      AND (
        s.created_at <= v_raw_max_created_at       -- Stay inside this run's frozen cutoff.
        OR s.created_at IS NULL                    -- Include missing upload time in diagnostics.
      );

    SELECT COUNT(*)
    INTO v_source_rows                             -- Count all raw rows visible to the full run.
    FROM smartwatchhigh AS s
    WHERE s.created_at <= v_raw_max_created_at
       OR s.created_at IS NULL;
  ELSE                                             -- Incremental mode reports affected minutes' dates.
    INSERT INTO tmp_smartwatchhigh_days (event_date)
    SELECT DISTINCT DATE(m.minute_ts)
    FROM tmp_smartwatchhigh_minutes AS m;

    SELECT COUNT(*)
    INTO v_source_rows                             -- Count raw rows used to rebuild affected minutes.
    FROM tmp_smartwatchhigh_device_map AS dm
    INNER JOIN smartwatchhigh AS s
      ON s.deviceId = dm.deviceId
    INNER JOIN tmp_smartwatchhigh_minutes AS m
      ON m.userId = dm.userId
     AND m.minute_ts = TIMESTAMP(
       DATE(s.event_ts),
       MAKETIME(HOUR(s.event_ts), MINUTE(s.event_ts), 0)
     )
    WHERE s.created_at <= v_raw_max_created_at
       OR s.created_at IS NULL;
  END IF;

  SELECT COUNT(*)
  INTO v_affected_days                             -- Save the number of dates represented by this run.
  FROM tmp_smartwatchhigh_days;

  DROP TEMPORARY TABLE IF EXISTS tmp_smartwatchhigh_run_users; -- Clear this session's prior helper.
  CREATE TEMPORARY TABLE tmp_smartwatchhigh_run_users (
    userId BIGINT NOT NULL,
    PRIMARY KEY (userId)                           -- Process each participant only once.
  ) ENGINE = InnoDB;

  IF v_is_full THEN                                -- Full mode processes every resolved participant.
    INSERT INTO tmp_smartwatchhigh_run_users (userId)
    SELECT DISTINCT dm.userId
    FROM tmp_smartwatchhigh_device_map AS dm;
  ELSE                                             -- Incremental mode processes affected users only.
    INSERT INTO tmp_smartwatchhigh_run_users (userId)
    SELECT DISTINCT m.userId
    FROM tmp_smartwatchhigh_minutes AS m;
  END IF;

  IF NOT v_is_full THEN                            -- Keep the complete increment all-or-nothing.
    START TRANSACTION;

    DELETE t
    FROM smartwatchhigh_tidy AS t
    INNER JOIN tmp_smartwatchhigh_minutes AS m
      ON m.userId = t.userId
     AND m.minute_ts = t.minute_ts;                -- Remove prior versions of affected keys.
    SET v_deleted_rows = ROW_COUNT();              -- Capture the deletion count immediately.
  END IF;

  SET v_cursor_done = FALSE;                       -- Prepare to read the participant cursor.
  OPEN cur_smartwatchhigh_users;

  participant_loop: LOOP
    FETCH cur_smartwatchhigh_users INTO v_user_id; -- Select one participant for this batch.

    IF v_cursor_done THEN                          -- FETCH sets this after the final participant.
      LEAVE participant_loop;
    END IF;

    IF v_is_full THEN                              -- Bound full-build locks to one participant.
      START TRANSACTION;
    END IF;

    INSERT INTO smartwatchhigh_tidy (              -- Map final values to explicit output columns.
      userId,
      minute_ts,
      bucket_5min,
      event_ts,
      created_at,
      deviceId,
      firmware,
      heartrate,
      oxygens,
      breathrate,
      sleeprate
    )
    WITH
    required_rows AS (                            -- Step 1: select valid technical fields.
      SELECT
        dm.userId,
        s.deviceId,
        s.firmware,
        s.event_ts,
        s.created_at,
        TIMESTAMP(
          DATE(s.event_ts),
          MAKETIME(HOUR(s.event_ts), MINUTE(s.event_ts), 0)
        ) AS minute_ts,                            -- Beginning of the raw event minute.
        s.heartrate,
        s.oxygens,
        s.breathrate,
        s.sleeprate,
        MIN(s.created_at) OVER (
          PARTITION BY s.deviceId, s.firmware, s.event_ts
        ) AS first_created_at                      -- Earliest upload of the exact device event.
      FROM tmp_smartwatchhigh_device_map AS dm
      INNER JOIN smartwatchhigh AS s
        ON s.deviceId = dm.deviceId               -- Read the current participant's devices.
      LEFT JOIN tmp_smartwatchhigh_minutes AS scope
        ON scope.userId = dm.userId
       AND scope.minute_ts = TIMESTAMP(
         DATE(s.event_ts),
         MAKETIME(HOUR(s.event_ts), MINUTE(s.event_ts), 0)
       )
      WHERE dm.userId = v_user_id                 -- Keep this statement participant-sized.
        AND (v_is_full OR scope.userId IS NOT NULL) -- Full history or affected incremental keys.
        AND s.firmware IS NOT NULL                -- Required by the exact-event key.
        AND TRIM(s.firmware) <> ''                -- Reject blank firmware values.
        AND s.event_ts IS NOT NULL                -- Required to construct the analytical minute.
        AND s.created_at IS NOT NULL              -- Required by incremental processing.
        AND s.created_at <= v_raw_max_created_at  -- Apply this run's frozen upper cutoff.
    ),

    earliest_payloads AS (                        -- Step 2: keep the earliest upload only.
      SELECT
        userId,
        deviceId,
        firmware,
        event_ts,
        created_at,
        minute_ts,
        heartrate,
        oxygens,
        breathrate,
        sleeprate
      FROM required_rows
      WHERE created_at = first_created_at          -- Ignore later copies of the same event.
      GROUP BY                                     -- Collapse completely equal earliest copies.
        userId,
        deviceId,
        firmware,
        event_ts,
        created_at,
        minute_ts,
        heartrate,
        oxygens,
        breathrate,
        sleeprate
    ),

    event_checked AS (                            -- Step 3: detect conflicting earliest payloads.
      SELECT
        p.*,
        COUNT(*) OVER (
          PARTITION BY p.deviceId, p.firmware, p.event_ts
        ) AS payload_n                            -- More than one means measurements disagree.
      FROM earliest_payloads AS p
    ),

    device_minute_checked AS (                    -- Step 4: detect several events in one minute.
      SELECT
        e.*,
        COUNT(*) OVER (
          PARTITION BY e.deviceId, e.firmware, e.minute_ts
        ) AS event_n                              -- More than one makes the device-minute ambiguous.
      FROM event_checked AS e
      WHERE e.payload_n = 1                       -- Remove conflicting exact events first.
    ),

    cleaned_values AS (                           -- Step 5: clean each measurement independently.
      SELECT
        userId,
        deviceId,
        firmware,
        event_ts,
        created_at,
        minute_ts,
        CASE
          WHEN heartrate > 0 THEN heartrate
          ELSE NULL
        END AS heartrate,
        CASE
          WHEN oxygens BETWEEN 1 AND 100 THEN oxygens
          ELSE NULL
        END AS oxygens,
        CASE
          WHEN breathrate BETWEEN 1 AND 100 THEN breathrate
          ELSE NULL
        END AS breathrate,
        CASE
          WHEN sleeprate BETWEEN 0 AND 4 THEN sleeprate -- Keep zero; its semantic label is unresolved.
          ELSE NULL
        END AS sleeprate
      FROM device_minute_checked
      WHERE event_n = 1                           -- Keep one unambiguous event per device-minute.
    ),

    usable_rows AS (                              -- Step 6: remove rows with no usable measurement.
      SELECT
        userId,
        deviceId,
        firmware,
        event_ts,
        created_at,
        minute_ts,
        heartrate,
        oxygens,
        breathrate,
        sleeprate
      FROM cleaned_values
      WHERE heartrate IS NOT NULL
         OR oxygens IS NOT NULL
         OR breathrate IS NOT NULL
         OR sleeprate IS NOT NULL
    ),

    participant_minute_checked AS (               -- Step 7: enforce participant-minute uniqueness.
      SELECT
        p.*,
        COUNT(*) OVER (
          PARTITION BY p.userId, p.minute_ts
        ) AS candidate_n                          -- Detect multiple devices or firmware versions.
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
      heartrate,
      oxygens,
      breathrate,
      sleeprate
    FROM participant_minute_checked
    WHERE candidate_n = 1;                        -- Never choose arbitrarily between candidates.

    SET v_batch_inserted_rows = ROW_COUNT();      -- Capture this participant's inserted rows.
    SET v_inserted_rows =                         -- Accumulate the complete run's insert count.
      v_inserted_rows + v_batch_inserted_rows;

    IF v_is_full THEN                             -- Release this participant's InnoDB locks now.
      COMMIT;
    END IF;
  END LOOP;

  CLOSE cur_smartwatchhigh_users;

  IF NOT v_is_full THEN                           -- Finish the one incremental transaction.
    COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_total_rows                               -- Count the complete final tidy table.
  FROM smartwatchhigh_tidy;

  IF v_is_full AND v_total_rows = 0 THEN          -- Never report an empty full build as successful.
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'smartwatchhigh full build produced no tidy rows';
  END IF;

  SET v_finished_at = UTC_TIMESTAMP(6);           -- Record successful completion time.
  SET SESSION time_zone = v_old_time_zone;        -- Restore the caller's original timezone.

  SELECT
    IF(v_is_full, 'full', 'incremental') AS run_mode, -- Report the selected refresh mode.
    v_started_at AS started_at,                   -- UTC start of the procedure call.
    v_finished_at AS finished_at,                 -- UTC end of the successful procedure call.
    v_previous_created_at AS previous_created_at, -- Watermark found before this run.
    v_raw_max_created_at AS raw_max_created_at,   -- Raw upper cutoff used by this run.
    v_affected_days AS affected_days,             -- Event dates represented by the selected scope.
    v_source_rows AS source_rows,                 -- Raw rows read for that scope.
    v_deleted_rows AS deleted_tidy_rows,          -- Existing tidy rows removed by this run.
    v_inserted_rows AS inserted_tidy_rows,        -- Clean tidy rows inserted by this run.
    v_total_rows AS total_tidy_rows;              -- Return one non-persistent summary row.
END//


-- Restore the normal client delimiter for subsequent SQL statements.
DELIMITER ;
