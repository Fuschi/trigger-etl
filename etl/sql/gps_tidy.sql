-- ============================================================================
-- gps_tidy.sql
--
-- Source tables (read only):
--   gps(deviceId, firmware, event_ts DATETIME, created_at TIMESTAMP,
--       longitude, latitude, accuracy)
--   user_gps(deviceId, userId)
--
-- Managed objects:
--   gps_tidy
--   etl_gps_tidy()
--
-- Usage:
--   CALL etl_gps_tidy();
--
-- An empty gps_tidy triggers a full build. Otherwise the procedure finds raw
-- rows whose created_at is greater than MAX(gps_tidy.created_at), then fully
-- rebuilds their event dates.
-- ============================================================================


CREATE TABLE IF NOT EXISTS gps_tidy (             -- Preserve the table if it already exists.
  userId      BIGINT       NOT NULL,              -- Pseudonymous participant identifier.
  minute_ts   DATETIME(6)  NOT NULL,              -- UTC event minute, with seconds set to zero.
  bucket_5min DATETIME(6)  NOT NULL,              -- Start of the containing UTC five-minute bucket.
  event_ts    DATETIME(6)  NOT NULL,              -- Original event timestamp generated in raw GPS.
  created_at  DATETIME(6)  NOT NULL,              -- Raw ingestion time, read and stored in UTC.
  deviceId    VARCHAR(128) NOT NULL,              -- Source device, retained as provenance.
  firmware    VARCHAR(128) NOT NULL,              -- Source firmware, retained as provenance.
  longitude   DOUBLE       NOT NULL,              -- Longitude in decimal degrees.
  latitude    DOUBLE       NOT NULL,              -- Latitude in decimal degrees.
  accuracy    DOUBLE       NULL,                  -- Horizontal accuracy; invalid values become NULL.

  PRIMARY KEY (userId, minute_ts),                -- Enforce at most one row per participant-minute.
  INDEX idx_gps_tidy_user_bucket (userId, bucket_5min), -- Support participant time-series queries.
  INDEX idx_gps_tidy_bucket (bucket_5min),        -- Support queries by shared five-minute bucket.
  INDEX idx_gps_tidy_created_at (created_at),     -- Speed up the incremental MAX(created_at) lookup.

  CONSTRAINT chk_gps_tidy_longitude
    CHECK (longitude BETWEEN -180 AND 180),       -- Reject impossible longitude values.
  CONSTRAINT chk_gps_tidy_latitude
    CHECK (latitude BETWEEN -90 AND 90),          -- Reject impossible latitude values.
  CONSTRAINT chk_gps_tidy_accuracy
    CHECK (accuracy IS NULL OR accuracy > 0)      -- Allow only positive accuracy or NULL.
) ENGINE = InnoDB;                                -- InnoDB provides transactional DELETE/INSERT.


-- Use // so the semicolons inside the procedure do not end CREATE PROCEDURE.
DELIMITER //


CREATE OR REPLACE PROCEDURE etl_gps_tidy()         -- Replace the definition, not the output table.
SQL SECURITY INVOKER                              -- Use the privileges of the account running CALL.
MODIFIES SQL DATA                                 -- Declare that the procedure writes database data.
main: BEGIN                                       -- Open a named code block; this is not a transaction.
  DECLARE v_started_at DATETIME(6);               -- UTC procedure start time.
  DECLARE v_finished_at DATETIME(6);              -- UTC procedure finish time.
  DECLARE v_previous_created_at DATETIME(6) DEFAULT NULL; -- Current tidy ingestion watermark.
  DECLARE v_raw_max_created_at DATETIME(6) DEFAULT NULL;  -- Raw upper cutoff for this run.
  DECLARE v_old_time_zone VARCHAR(64);             -- Session timezone to restore before returning.
  DECLARE v_is_full BOOLEAN DEFAULT FALSE;         -- TRUE only when gps_tidy is empty.

  DECLARE v_affected_days BIGINT UNSIGNED DEFAULT 0; -- Number of event dates rebuilt.
  DECLARE v_source_rows BIGINT UNSIGNED DEFAULT 0;   -- Raw rows in the dates being rebuilt.
  DECLARE v_deleted_rows BIGINT UNSIGNED DEFAULT 0;  -- Tidy rows removed before rebuilding.
  DECLARE v_inserted_rows BIGINT UNSIGNED DEFAULT 0; -- Clean rows inserted by this run.
  DECLARE v_total_rows BIGINT UNSIGNED DEFAULT 0;    -- Final gps_tidy row count.

  DECLARE EXIT HANDLER FOR SQLEXCEPTION            -- Catch any SQL error raised below.
  BEGIN                                             -- Begin the error-handling code block.
    ROLLBACK;                                       -- Undo this run's DELETE and INSERT.

    IF v_old_time_zone IS NOT NULL THEN             -- Restore it only if it was saved.
      SET SESSION time_zone = v_old_time_zone;      -- Do not alter the caller's later queries.
    END IF;

    RESIGNAL;                                       -- Return the original error to the caller.
  END;

  SET v_old_time_zone = @@SESSION.time_zone;        -- Remember the caller's current timezone.
  -- gps.created_at is TIMESTAMP: read it in UTC before storing it as DATETIME.
  SET SESSION time_zone = '+00:00';                 -- Make TIMESTAMP reads explicitly UTC.
  SET v_started_at = UTC_TIMESTAMP(6);              -- Record when this run started.

  START TRANSACTION;                                -- DELETE and INSERT must succeed together.

  -- These two maxima are read from the same transaction snapshot.
  SELECT MAX(t.created_at)
  INTO v_previous_created_at                        -- Store the current tidy watermark.
  FROM gps_tidy AS t;                               -- NULL means that gps_tidy is empty.

  SELECT MAX(g.created_at)
  INTO v_raw_max_created_at                         -- Freeze the raw upper cutoff for this run.
  FROM gps AS g;                                    -- Later raw uploads wait for the next run.

  -- created_at is NOT NULL in gps_tidy, so a NULL maximum means it is empty.
  SET v_is_full = (v_previous_created_at IS NULL);  -- Choose full or incremental automatically.

  DROP TEMPORARY TABLE IF EXISTS tmp_gps_days;      -- Clear leftovers in the same DB session.
  CREATE TEMPORARY TABLE tmp_gps_days (             -- Visible only to this connection.
    event_date DATE NOT NULL,                       -- Calendar date derived from event_ts.
    PRIMARY KEY (event_date)                        -- Store each affected date once.
  ) ENGINE = InnoDB;                                -- Keep temporary changes transactional.

  IF v_is_full THEN                                 -- gps_tidy is empty: process all dates.
    -- Full mode rebuilds every event date currently visible in raw GPS.
    INSERT INTO tmp_gps_days (event_date)           -- Build the list of dates to rebuild.
    SELECT DISTINCT DATE(g.event_ts)                -- Remove time and repeated dates.
    FROM gps AS g
    WHERE g.event_ts IS NOT NULL                    -- A missing event time has no event date.
      AND (
        g.created_at <= v_raw_max_created_at        -- Stay inside this run's raw cutoff.
        OR g.created_at IS NULL                     -- Include its date in full diagnostics.
      );
  ELSE                                              -- gps_tidy has data: process only new uploads.
    -- Incremental mode has no fixed time window and no separate state table.
    INSERT INTO tmp_gps_days (event_date)           -- Collect dates touched by new raw rows.
    SELECT DISTINCT DATE(g.event_ts)                -- A late upload can select an old event date.
    FROM gps AS g
    WHERE g.event_ts IS NOT NULL                    -- Ignore rows without an event date.
      AND g.created_at > v_previous_created_at      -- Select uploads newer than tidy's maximum.
      AND g.created_at <= v_raw_max_created_at;     -- Exclude uploads beyond this run's cutoff.
  END IF;

  SELECT COUNT(*)
  INTO v_affected_days                              -- Save the number of dates to rebuild.
  FROM tmp_gps_days;

  SELECT COUNT(*)
  INTO v_source_rows                                -- Count all raw rows in affected dates.
  FROM gps AS g
  INNER JOIN tmp_gps_days AS d
    ON d.event_date = DATE(g.event_ts)              -- Rebuild complete days, not only new rows.
  WHERE g.created_at <= v_raw_max_created_at        -- Use the same raw cutoff as above.
     OR g.created_at IS NULL;                       -- Count rows later rejected for missing upload time.

  IF v_is_full THEN                                 -- Full mode replaces every tidy row.
    -- DELETE remains in the same transaction as the following INSERT.
    DELETE FROM gps_tidy;                           -- Preserve the table definition and indexes.
    SET v_deleted_rows = ROW_COUNT();               -- Read the affected rows immediately.
  ELSE                                              -- Incremental mode replaces affected dates only.
    DELETE t                                        -- Delete rows through alias t.
    FROM gps_tidy AS t
    INNER JOIN tmp_gps_days AS d
      ON d.event_date = DATE(t.event_ts);           -- Match tidy rows by their event date.
    SET v_deleted_rows = ROW_COUNT();               -- Save the incremental deletion count.
  END IF;

  INSERT INTO gps_tidy (                            -- Map the final SELECT to explicit output columns.
    userId,
    minute_ts,
    bucket_5min,
    event_ts,
    created_at,
    deviceId,
    firmware,
    longitude,
    latitude,
    accuracy
  )
  WITH                                               -- Start the in-memory cleaning pipeline.
  required_rows AS (                                -- Step 1: keep required technical fields.
    SELECT
      g.deviceId,
      g.firmware,
      g.event_ts,
      g.created_at,
      TIMESTAMP(                                     -- Recombine the date and truncated time.
        DATE(g.event_ts),                            -- Keep the event calendar date.
        MAKETIME(HOUR(g.event_ts), MINUTE(g.event_ts), 0) -- Set seconds to zero.
      ) AS minute_ts,                                -- Result: beginning of the event minute.
      g.longitude,
      g.latitude,
      g.accuracy,
      MIN(g.created_at) OVER (                       -- Window function: do not collapse rows yet.
        PARTITION BY g.deviceId, g.firmware, g.event_ts -- Define one exact device event.
      ) AS first_created_at                          -- Earliest upload time for that event.
    FROM gps AS g
    INNER JOIN tmp_gps_days AS d
      ON d.event_date = DATE(g.event_ts)             -- Read only dates selected for rebuilding.
    WHERE g.deviceId IS NOT NULL                     -- deviceId is part of every deduplication key.
      AND TRIM(g.deviceId) <> ''                     -- Reject empty or whitespace-only IDs.
      AND g.firmware IS NOT NULL                     -- Firmware is retained as provenance.
      AND TRIM(g.firmware) <> ''                     -- Reject empty or whitespace-only firmware.
      AND g.event_ts IS NOT NULL                     -- The analytical minute requires event time.
      AND g.created_at IS NOT NULL                   -- Incremental processing requires upload time.
      AND g.created_at <= v_raw_max_created_at       -- Keep the run internally consistent.
  ),

  -- Keep the earliest upload and collapse completely equal copies.
  earliest_payloads AS (                             -- Step 2: keep the earliest upload only.
    SELECT
      deviceId,
      firmware,
      event_ts,
      created_at,
      minute_ts,
      longitude,
      latitude,
      accuracy
    FROM required_rows
    WHERE created_at = first_created_at              -- Discard later uploads of the same event.
    GROUP BY                                         -- Collapse completely identical copies.
      deviceId,
      firmware,
      event_ts,
      created_at,
      minute_ts,
      longitude,
      latitude,
      accuracy
  ),

  event_checked AS (                                 -- Step 3: identify conflicting event payloads.
    SELECT
      p.*,                                           -- Carry every cleaned payload column forward.
      COUNT(*) OVER (                                -- Count distinct earliest payloads per event.
        PARTITION BY p.deviceId, p.firmware, p.event_ts -- Reuse the exact event key.
      ) AS payload_n                                 -- Values above 1 mean an unresolved conflict.
    FROM earliest_payloads AS p
  ),

  device_minute_checked AS (                         -- Step 4: inspect each device-minute.
    SELECT
      e.*,                                           -- Carry unambiguous events forward.
      COUNT(*) OVER (                                -- Count events without collapsing them.
        PARTITION BY e.deviceId, e.firmware, e.minute_ts -- Define one device/firmware-minute.
      ) AS event_n                                   -- Values above 1 make the minute ambiguous.
    FROM event_checked AS e
    WHERE e.payload_n = 1                            -- Exclude conflicting event payloads.
  ),

  valid_positions AS (                               -- Step 5: apply minimal position checks.
    SELECT
      deviceId,
      firmware,
      event_ts,
      created_at,
      minute_ts,
      longitude,
      latitude,
      CASE                                           -- Clean one value without dropping the row.
        WHEN accuracy > 0 THEN accuracy              -- Positive accuracy is technically usable.
        ELSE NULL                                    -- Zero, negative or missing becomes unknown.
      END AS accuracy
    FROM device_minute_checked
    WHERE event_n = 1                                -- Keep one unambiguous event per device-minute.
      AND longitude BETWEEN -180 AND 180             -- Enforce the physical longitude bounds.
      AND latitude BETWEEN -90 AND 90                -- Enforce the physical latitude bounds.
  ),

  device_map AS (                                    -- Step 6: summarize device-to-user mappings.
    SELECT
      ug.deviceId,
      MIN(ug.userId) AS userId,                      -- Safe only when user_n equals one.
      COUNT(DISTINCT ug.userId) AS user_n            -- Detect devices assigned to several users.
    FROM user_gps AS ug
    WHERE ug.deviceId IS NOT NULL                    -- A missing device cannot be joined to GPS.
      AND TRIM(ug.deviceId) <> ''                    -- Ignore empty or whitespace-only IDs.
    GROUP BY ug.deviceId                             -- Produce one mapping summary per device.
  ),

  participant_rows AS (                              -- Step 7: attach the participant identifier.
    SELECT
      m.userId,
      p.deviceId,
      p.firmware,
      p.event_ts,
      p.created_at,
      p.minute_ts,
      p.longitude,
      p.latitude,
      p.accuracy
    FROM valid_positions AS p
    INNER JOIN device_map AS m
      ON m.deviceId = p.deviceId                     -- Unmapped devices disappear in this inner join.
    WHERE m.user_n = 1                               -- Keep only unambiguous device ownership.
  ),

  participant_minute_checked AS (                    -- Step 8: inspect each participant-minute.
    SELECT
      p.*,                                           -- Carry participant positions forward.
      COUNT(*) OVER (                                -- Count candidates without collapsing them.
        PARTITION BY p.userId, p.minute_ts           -- This matches the output primary key.
      ) AS candidate_n                               -- Values above 1 mean multiple devices/events.
    FROM participant_rows AS p
  )

  SELECT
    userId,
    minute_ts,
    minute_ts - INTERVAL (MINUTE(minute_ts) MOD 5) MINUTE, -- Floor minute_ts to a 5-minute boundary.
    event_ts,
    created_at,
    deviceId,
    firmware,
    longitude,
    latitude,
    accuracy
  FROM participant_minute_checked
  WHERE candidate_n = 1;                            -- Insert only unique participant-minutes.

  SET v_inserted_rows = ROW_COUNT();                 -- Capture INSERT count before another statement.

  SELECT COUNT(*)
  INTO v_total_rows                                  -- Count the complete final tidy table.
  FROM gps_tidy;

  COMMIT;                                            -- Make DELETE and INSERT permanent together.

  SET v_finished_at = UTC_TIMESTAMP(6);              -- Record successful completion time.
  SET SESSION time_zone = v_old_time_zone;           -- Restore the caller's original timezone.

  SELECT
    IF(v_is_full, 'full', 'incremental') AS run_mode, -- Report the automatically selected mode.
    v_started_at AS started_at,                      -- UTC start of the procedure call.
    v_finished_at AS finished_at,                    -- UTC end of the successful procedure call.
    v_previous_created_at AS previous_created_at,    -- Watermark found in tidy before this run.
    v_raw_max_created_at AS raw_max_created_at,      -- Raw upper cutoff used by this run.
    v_affected_days AS affected_days,                -- Number of complete event dates rebuilt.
    v_source_rows AS source_rows,                    -- Raw rows seen in those event dates.
    v_deleted_rows AS deleted_tidy_rows,             -- Existing tidy rows removed by this run.
    v_inserted_rows AS inserted_tidy_rows,           -- Clean tidy rows inserted by this run.
    v_total_rows AS total_tidy_rows;                 -- Return one non-persistent run summary row.
  -- Close the named main procedure block using the temporary // delimiter.
END//


-- Restore the normal client delimiter for subsequent SQL statements.
DELIMITER ;
