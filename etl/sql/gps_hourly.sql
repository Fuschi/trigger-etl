-- One row per participant and UTC hour.
-- Means weight available five-minute means equally.
-- Each variable has its own five-minute and minute counts. Full rebuild.

CREATE TABLE IF NOT EXISTS gps_hourly (
  userId BIGINT NOT NULL,
  hour_ts DATETIME(6) NOT NULL,
  source_created_at_max DATETIME(6) NOT NULL,
  observed_5min_n TINYINT UNSIGNED NOT NULL,
  observed_minute_n TINYINT UNSIGNED NOT NULL,

  mixed_device_5min_n TINYINT UNSIGNED NOT NULL,
  mixed_firmware_5min_n TINYINT UNSIGNED NOT NULL,
  deviceId VARCHAR(128) NULL,
  firmware VARCHAR(128) NULL,

  longitude_5min_n TINYINT UNSIGNED NOT NULL,
  longitude_minute_n TINYINT UNSIGNED NOT NULL,
  latitude_5min_n TINYINT UNSIGNED NOT NULL,
  latitude_minute_n TINYINT UNSIGNED NOT NULL,
  longitude_mean DOUBLE NOT NULL,
  longitude_min DOUBLE NOT NULL,
  longitude_max DOUBLE NOT NULL,
  latitude_mean DOUBLE NOT NULL,
  latitude_min DOUBLE NOT NULL,
  latitude_max DOUBLE NOT NULL,
  accuracy_mean DOUBLE NOT NULL,
  accuracy_min DOUBLE NOT NULL,
  accuracy_max DOUBLE NOT NULL,
  accuracy_5min_n TINYINT UNSIGNED NOT NULL,
  accuracy_minute_n TINYINT UNSIGNED NOT NULL,

  PRIMARY KEY (userId, hour_ts),
  INDEX idx_gps_hourly_hour (hour_ts),
  INDEX idx_gps_hourly_source_created (source_created_at_max),

  CONSTRAINT chk_gps_hourly_boundary
    CHECK (MINUTE(hour_ts) = 0 AND SECOND(hour_ts) = 0 AND MICROSECOND(hour_ts) = 0),
  CONSTRAINT chk_gps_hourly_coverage
    CHECK (observed_5min_n BETWEEN 1 AND 12
       AND observed_minute_n BETWEEN observed_5min_n AND 60
       AND accuracy_5min_n = observed_5min_n
       AND accuracy_minute_n = observed_minute_n),
  CONSTRAINT chk_gps_hourly_provenance
    CHECK (mixed_device_5min_n BETWEEN 0 AND observed_5min_n
       AND mixed_firmware_5min_n BETWEEN 0 AND observed_5min_n
       AND (deviceId IS NULL OR mixed_device_5min_n = 0)
       AND (firmware IS NULL OR mixed_firmware_5min_n = 0)),
  CONSTRAINT chk_gps_hourly_coordinate_counts
    CHECK (longitude_5min_n = observed_5min_n AND latitude_5min_n = observed_5min_n
       AND longitude_minute_n = observed_minute_n AND latitude_minute_n = observed_minute_n),
  CONSTRAINT chk_gps_hourly_longitude
    CHECK (longitude_min BETWEEN -180 AND 180 AND longitude_max BETWEEN -180 AND 180
       AND longitude_min <= longitude_mean AND longitude_mean <= longitude_max),
  CONSTRAINT chk_gps_hourly_latitude
    CHECK (latitude_min BETWEEN -90 AND 90 AND latitude_max BETWEEN -90 AND 90
       AND latitude_min <= latitude_mean AND latitude_mean <= latitude_max),
  CONSTRAINT chk_gps_hourly_accuracy
    CHECK (accuracy_min <= accuracy_mean AND accuracy_mean <= accuracy_max)
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
    ROLLBACK;
    RESIGNAL;
  END;

  SET v_started_at = UTC_TIMESTAMP(6);
  START TRANSACTION WITH CONSISTENT SNAPSHOT;

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
    longitude_5min_n, longitude_minute_n, latitude_5min_n, latitude_minute_n,
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
    COUNT(f.longitude_mean), SUM(f.longitude_n), COUNT(f.latitude_mean), SUM(f.latitude_n),
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
