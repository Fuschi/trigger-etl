-- ============================================================================
-- gps_5min.sql
--
-- Source table (read only):
--   gps_tidy(userId, minute_ts, bucket_5min, created_at,
--            deviceId, firmware, longitude, latitude, accuracy)
--
-- Managed objects:
--   gps_5min
--   etl_gps_5min()
--
-- Usage:
--   CALL etl_gps_5min();
--
-- This canonical implementation performs one transactional full rebuild.
-- It intentionally has no incremental watermark because a watermark over the
-- current tidy rows cannot detect a tidy row that was deleted by a correction.
-- ============================================================================


CREATE TABLE IF NOT EXISTS gps_5min (              -- Preserve a compatible existing table.
  userId      BIGINT      NOT NULL,                -- Pseudonymous participant identifier.
  bucket_5min DATETIME(6) NOT NULL,                -- Beginning of the UTC five-minute interval.

  source_created_at_max DATETIME(6) NOT NULL,      -- Greatest tidy ingestion time represented.
  observed_minute_n TINYINT UNSIGNED NOT NULL,     -- Distinct observed minutes, from 1 through 5.

  device_n   TINYINT UNSIGNED NOT NULL,            -- Distinct source devices in the bucket.
  firmware_n TINYINT UNSIGNED NOT NULL,            -- Distinct firmware values in the bucket.
  deviceId   VARCHAR(128) NULL,                    -- Populated only when exactly one device occurs.
  firmware   VARCHAR(128) NULL,                    -- Populated only when exactly one firmware occurs.

  longitude_mean DOUBLE NOT NULL,                 -- Arithmetic mean longitude in decimal degrees.
  longitude_min  DOUBLE NOT NULL,                 -- Minimum observed longitude.
  longitude_max  DOUBLE NOT NULL,                 -- Maximum observed longitude.
  latitude_mean  DOUBLE NOT NULL,                 -- Arithmetic mean latitude in decimal degrees.
  latitude_min   DOUBLE NOT NULL,                 -- Minimum observed latitude.
  latitude_max   DOUBLE NOT NULL,                 -- Maximum observed latitude.

  accuracy_mean DOUBLE NULL,                      -- Mean available horizontal accuracy in metres.
  accuracy_min  DOUBLE NULL,                      -- Minimum available horizontal accuracy.
  accuracy_max  DOUBLE NULL,                      -- Maximum available horizontal accuracy.
  accuracy_n    TINYINT UNSIGNED NOT NULL,         -- Minutes contributing a non-null accuracy.

  PRIMARY KEY (userId, bucket_5min),              -- Enforce one row per participant/bucket.
  INDEX idx_gps_5min_bucket (bucket_5min),         -- Support shared-time joins and coverage queries.
  INDEX idx_gps_5min_source_created (source_created_at_max), -- Inspect aggregate freshness.

  CONSTRAINT chk_gps_5min_bucket_boundary
    CHECK (MOD(MINUTE(bucket_5min), 5) = 0
       AND SECOND(bucket_5min) = 0
       AND MICROSECOND(bucket_5min) = 0),          -- Enforce a fixed five-minute UTC boundary.
  CONSTRAINT chk_gps_5min_observed_minutes
    CHECK (observed_minute_n BETWEEN 1 AND 5),     -- A fixed bucket contains at most five minutes.
  CONSTRAINT chk_gps_5min_provenance_counts
    CHECK (device_n BETWEEN 1 AND observed_minute_n
       AND firmware_n BETWEEN 1 AND observed_minute_n), -- Provenance comes from observed minutes.
  CONSTRAINT chk_gps_5min_device_value
    CHECK ((device_n = 1 AND deviceId IS NOT NULL)
        OR (device_n > 1 AND deviceId IS NULL)),   -- Never select one device from a transition.
  CONSTRAINT chk_gps_5min_firmware_value
    CHECK ((firmware_n = 1 AND firmware IS NOT NULL)
        OR (firmware_n > 1 AND firmware IS NULL)), -- Never select one firmware from a transition.
  CONSTRAINT chk_gps_5min_longitude
    CHECK (longitude_min BETWEEN -180 AND 180
       AND longitude_mean BETWEEN -180 AND 180
       AND longitude_max BETWEEN -180 AND 180
       AND longitude_min <= longitude_mean
       AND longitude_mean <= longitude_max),      -- Preserve physical coordinate ordering.
  CONSTRAINT chk_gps_5min_latitude
    CHECK (latitude_min BETWEEN -90 AND 90
       AND latitude_mean BETWEEN -90 AND 90
       AND latitude_max BETWEEN -90 AND 90
       AND latitude_min <= latitude_mean
       AND latitude_mean <= latitude_max),        -- Preserve physical coordinate ordering.
  CONSTRAINT chk_gps_5min_accuracy_count
    CHECK (accuracy_n BETWEEN 0 AND observed_minute_n), -- Accuracy cannot outnumber positions.
  CONSTRAINT chk_gps_5min_accuracy_values
    CHECK (                                        -- Statistics are all present or all absent.
      (accuracy_n = 0
       AND accuracy_mean IS NULL
       AND accuracy_min IS NULL
       AND accuracy_max IS NULL)
      OR
      (accuracy_n > 0
       AND accuracy_mean IS NOT NULL
       AND accuracy_min IS NOT NULL
       AND accuracy_max IS NOT NULL
       AND accuracy_mean > 0
       AND accuracy_min > 0
       AND accuracy_max > 0
       AND accuracy_min <= accuracy_mean
       AND accuracy_mean <= accuracy_max)
    )
) ENGINE = InnoDB;                                 -- Full replacement is transactionally protected.


-- Use // so semicolons inside the procedure do not end CREATE PROCEDURE.
DELIMITER //


CREATE OR REPLACE PROCEDURE etl_gps_5min()        -- Replace the routine, not the output table.
SQL SECURITY INVOKER                              -- Use the privileges of the account running CALL.
MODIFIES SQL DATA                                 -- Declare that the procedure writes database data.
main: BEGIN                                       -- Open a named procedure block.
  DECLARE v_started_at DATETIME(6);               -- UTC procedure start time.
  DECLARE v_finished_at DATETIME(6);              -- UTC procedure finish time.
  DECLARE v_source_rows BIGINT UNSIGNED DEFAULT 0; -- Tidy rows read by this rebuild.
  DECLARE v_source_buckets BIGINT UNSIGNED DEFAULT 0; -- Distinct participant/bucket source keys.
  DECLARE v_deleted_rows BIGINT UNSIGNED DEFAULT 0; -- Previous aggregate rows removed.
  DECLARE v_inserted_rows BIGINT UNSIGNED DEFAULT 0; -- New aggregate rows inserted.
  DECLARE v_total_rows BIGINT UNSIGNED DEFAULT 0;  -- Final gps_5min row count.

  DECLARE EXIT HANDLER FOR SQLEXCEPTION           -- Catch any SQL error raised below.
  BEGIN
    ROLLBACK;                                     -- Restore the previous complete aggregate.
    RESIGNAL;                                     -- Return the original error to the caller.
  END;

  SET v_started_at = UTC_TIMESTAMP(6);            -- Record when the rebuild started.
  START TRANSACTION WITH CONSISTENT SNAPSHOT;      -- Read one stable tidy version throughout.

  SELECT COUNT(*)
  INTO v_source_rows                              -- Count every participant-minute source row.
  FROM gps_tidy;

  IF v_source_rows = 0 THEN                       -- Never erase a valid aggregate from an empty source.
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'gps_tidy is empty; gps_5min was not rebuilt';
  END IF;

  SELECT COUNT(*)
  INTO v_source_buckets                           -- Count expected analytical output keys.
  FROM (
    SELECT
      t.userId,
      t.bucket_5min
    FROM gps_tidy AS t
    GROUP BY
      t.userId,
      t.bucket_5min
  ) AS source_keys;

  DELETE FROM gps_5min;                           -- Preserve the reviewed schema and indexes.
  SET v_deleted_rows = ROW_COUNT();               -- Capture the deletion count immediately.

  INSERT INTO gps_5min (                          -- Map aggregates to explicit output columns.
    userId,
    bucket_5min,
    source_created_at_max,
    observed_minute_n,
    device_n,
    firmware_n,
    deviceId,
    firmware,
    longitude_mean,
    longitude_min,
    longitude_max,
    latitude_mean,
    latitude_min,
    latitude_max,
    accuracy_mean,
    accuracy_min,
    accuracy_max,
    accuracy_n
  )
  SELECT
    t.userId,
    t.bucket_5min,
    MAX(t.created_at) AS source_created_at_max,   -- Freshest represented raw-ingestion time.
    COUNT(DISTINCT t.minute_ts) AS observed_minute_n, -- Tidy guarantees one row per minute.
    COUNT(DISTINCT t.deviceId) AS device_n,
    COUNT(DISTINCT t.firmware) AS firmware_n,
    CASE
      WHEN COUNT(DISTINCT t.deviceId) = 1 THEN MIN(t.deviceId)
      ELSE NULL
    END AS deviceId,                              -- Preserve an identifier only when unambiguous.
    CASE
      WHEN COUNT(DISTINCT t.firmware) = 1 THEN MIN(t.firmware)
      ELSE NULL
    END AS firmware,                              -- Preserve firmware only when unambiguous.
    AVG(t.longitude) AS longitude_mean,
    MIN(t.longitude) AS longitude_min,
    MAX(t.longitude) AS longitude_max,
    AVG(t.latitude) AS latitude_mean,
    MIN(t.latitude) AS latitude_min,
    MAX(t.latitude) AS latitude_max,
    AVG(t.accuracy) AS accuracy_mean,             -- AVG, MIN and MAX ignore unavailable accuracy.
    MIN(t.accuracy) AS accuracy_min,
    MAX(t.accuracy) AS accuracy_max,
    COUNT(t.accuracy) AS accuracy_n
  FROM gps_tidy AS t
  GROUP BY
    t.userId,
    t.bucket_5min;

  SET v_inserted_rows = ROW_COUNT();              -- Capture the inserted aggregate count.

  IF v_inserted_rows <> v_source_buckets THEN     -- Every source key must yield exactly one row.
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'gps_5min output count differs from source bucket count';
  END IF;

  SELECT COUNT(*)
  INTO v_total_rows                               -- Verify the final table before committing.
  FROM gps_5min;

  IF v_total_rows <> v_source_buckets THEN        -- Protect against incomplete replacement.
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'gps_5min final count differs from source bucket count';
  END IF;

  COMMIT;                                         -- Make the complete replacement durable.

  SET v_finished_at = UTC_TIMESTAMP(6);           -- Record successful completion time.

  SELECT
    'full' AS run_mode,                           -- The procedure is deliberately full-only.
    v_started_at AS started_at,
    v_finished_at AS finished_at,
    v_source_rows AS source_rows,
    v_source_buckets AS source_buckets,
    v_deleted_rows AS deleted_5min_rows,
    v_inserted_rows AS inserted_5min_rows,
    v_total_rows AS total_5min_rows;              -- Return one non-persistent summary row.
END//


-- Restore the normal client delimiter for subsequent SQL statements.
DELIMITER ;
