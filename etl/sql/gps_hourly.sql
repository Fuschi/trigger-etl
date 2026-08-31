-- ============================================================================
-- gps_hourly.sql
--
-- Source table (read only): gps_5min
-- Managed objects: gps_hourly and etl_gps_hourly()
-- Grain: one row per participant and UTC hour.
-- Means give equal weight to each available five-minute bucket.
-- ============================================================================

CREATE TABLE IF NOT EXISTS gps_hourly (
  userId BIGINT NOT NULL,                         -- Pseudonymous participant identifier.
  hour_ts DATETIME(6) NOT NULL,                   -- Beginning of the UTC hour.
  source_created_at_max DATETIME(6) NOT NULL,     -- Freshest represented tidy ingestion time.
  observed_5min_n TINYINT UNSIGNED NOT NULL,      -- Represented five-minute buckets, 1 through 12.
  observed_minute_n TINYINT UNSIGNED NOT NULL,    -- Represented participant-minutes, 1 through 60.

  mixed_device_5min_n TINYINT UNSIGNED NOT NULL,  -- Source buckets already containing >1 device.
  mixed_firmware_5min_n TINYINT UNSIGNED NOT NULL,-- Source buckets already containing >1 firmware.
  deviceId VARCHAR(128) NULL,                     -- Present only when the complete hour is unambiguous.
  firmware VARCHAR(128) NULL,                     -- Present only when the complete hour is unambiguous.

  longitude_mean DOUBLE NOT NULL,                 -- Mean of available five-minute means.
  longitude_min DOUBLE NOT NULL,
  longitude_max DOUBLE NOT NULL,
  latitude_mean DOUBLE NOT NULL,
  latitude_min DOUBLE NOT NULL,
  latitude_max DOUBLE NOT NULL,
  accuracy_mean DOUBLE NULL,
  accuracy_min DOUBLE NULL,
  accuracy_max DOUBLE NULL,
  accuracy_5min_n TINYINT UNSIGNED NOT NULL,      -- Buckets contributing accuracy.
  accuracy_minute_n TINYINT UNSIGNED NOT NULL,    -- Underlying minutes contributing accuracy.

  PRIMARY KEY (userId, hour_ts),
  INDEX idx_gps_hourly_hour (hour_ts),
  INDEX idx_gps_hourly_source_created (source_created_at_max),

  CONSTRAINT chk_gps_hourly_boundary
    CHECK (MINUTE(hour_ts) = 0 AND SECOND(hour_ts) = 0 AND MICROSECOND(hour_ts) = 0),
  CONSTRAINT chk_gps_hourly_coverage
    CHECK (observed_5min_n BETWEEN 1 AND 12
       AND observed_minute_n BETWEEN observed_5min_n AND 60
       AND accuracy_5min_n BETWEEN 0 AND observed_5min_n
       AND accuracy_minute_n BETWEEN accuracy_5min_n AND observed_minute_n),
  CONSTRAINT chk_gps_hourly_provenance
    CHECK (mixed_device_5min_n BETWEEN 0 AND observed_5min_n
       AND mixed_firmware_5min_n BETWEEN 0 AND observed_5min_n
       AND (deviceId IS NULL OR mixed_device_5min_n = 0)
       AND (firmware IS NULL OR mixed_firmware_5min_n = 0)),
  CONSTRAINT chk_gps_hourly_longitude
    CHECK (longitude_min BETWEEN -180 AND 180 AND longitude_max BETWEEN -180 AND 180
       AND longitude_min <= longitude_mean AND longitude_mean <= longitude_max),
  CONSTRAINT chk_gps_hourly_latitude
    CHECK (latitude_min BETWEEN -90 AND 90 AND latitude_max BETWEEN -90 AND 90
       AND latitude_min <= latitude_mean AND latitude_mean <= latitude_max),
  CONSTRAINT chk_gps_hourly_accuracy
    CHECK ((accuracy_5min_n = 0 AND accuracy_minute_n = 0
            AND accuracy_mean IS NULL AND accuracy_min IS NULL AND accuracy_max IS NULL)
        OR (accuracy_5min_n > 0 AND accuracy_minute_n > 0
            AND accuracy_mean IS NOT NULL AND accuracy_min IS NOT NULL AND accuracy_max IS NOT NULL
            AND accuracy_min > 0 AND accuracy_min <= accuracy_mean AND accuracy_mean <= accuracy_max))
) ENGINE = InnoDB;

DELIMITER //

CREATE OR REPLACE PROCEDURE etl_gps_hourly()
SQL SECURITY INVOKER
MODIFIES SQL DATA
main: BEGIN
  DECLARE v_started_at DATETIME(6);
  DECLARE v_finished_at DATETIME(6);
  DECLARE v_source_rows BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_source_hours BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_deleted_rows BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_inserted_rows BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_total_rows BIGINT UNSIGNED DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;                                     -- Preserve the previous complete hourly table.
    RESIGNAL;
  END;

  SET v_started_at = UTC_TIMESTAMP(6);
  START TRANSACTION WITH CONSISTENT SNAPSHOT;      -- Read one stable five-minute snapshot.

  SELECT COUNT(*) INTO v_source_rows FROM gps_5min;
  IF v_source_rows = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'gps_5min is empty; gps_hourly was not rebuilt';
  END IF;

  SELECT COUNT(*) INTO v_source_hours
  FROM (
    SELECT userId, TIMESTAMP(DATE(bucket_5min), MAKETIME(HOUR(bucket_5min), 0, 0)) AS hour_ts
    FROM gps_5min GROUP BY userId, hour_ts
  ) AS source_keys;

  DELETE FROM gps_hourly;
  SET v_deleted_rows = ROW_COUNT();

  INSERT INTO gps_hourly (
    userId, hour_ts, source_created_at_max, observed_5min_n, observed_minute_n,
    mixed_device_5min_n, mixed_firmware_5min_n, deviceId, firmware,
    longitude_mean, longitude_min, longitude_max,
    latitude_mean, latitude_min, latitude_max,
    accuracy_mean, accuracy_min, accuracy_max, accuracy_5min_n, accuracy_minute_n
  )
  SELECT
    f.userId,
    TIMESTAMP(DATE(f.bucket_5min), MAKETIME(HOUR(f.bucket_5min), 0, 0)) AS hour_ts,
    MAX(f.source_created_at_max),
    COUNT(*),
    SUM(f.observed_minute_n),
    SUM(f.device_n > 1),
    SUM(f.firmware_n > 1),
    CASE WHEN SUM(f.device_n > 1) = 0 AND COUNT(DISTINCT f.deviceId) = 1 THEN MIN(f.deviceId) END,
    CASE WHEN SUM(f.firmware_n > 1) = 0 AND COUNT(DISTINCT f.firmware) = 1 THEN MIN(f.firmware) END,
    AVG(f.longitude_mean), MIN(f.longitude_min), MAX(f.longitude_max),
    AVG(f.latitude_mean), MIN(f.latitude_min), MAX(f.latitude_max),
    AVG(f.accuracy_mean), MIN(f.accuracy_min), MAX(f.accuracy_max),
    COUNT(f.accuracy_mean), SUM(f.accuracy_n)
  FROM gps_5min AS f
  GROUP BY f.userId, hour_ts;

  SET v_inserted_rows = ROW_COUNT();
  IF v_inserted_rows <> v_source_hours THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'gps_hourly output count differs from source hour count';
  END IF;

  SELECT COUNT(*) INTO v_total_rows FROM gps_hourly;
  IF v_total_rows <> v_source_hours THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'gps_hourly final count differs from source hour count';
  END IF;

  COMMIT;
  SET v_finished_at = UTC_TIMESTAMP(6);
  SELECT 'full' AS run_mode, v_started_at AS started_at, v_finished_at AS finished_at,
    v_source_rows AS source_5min_rows, v_source_hours AS source_hours,
    v_deleted_rows AS deleted_hourly_rows, v_inserted_rows AS inserted_hourly_rows,
    v_total_rows AS total_hourly_rows;
END//

DELIMITER ;
