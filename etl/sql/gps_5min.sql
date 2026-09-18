-- One row per participant and UTC five-minute bucket.
-- All *_n count non-NULL values, not accuracy quality.
-- Statistics remain numeric for existing analyses. Full transactional rebuild.

CREATE TABLE IF NOT EXISTS gps_5min (
  userId      BIGINT      NOT NULL,
  bucket_5min DATETIME(6) NOT NULL,

  source_created_at_max DATETIME(6) NOT NULL,
  observed_minute_n TINYINT UNSIGNED NOT NULL,

  device_n   TINYINT UNSIGNED NOT NULL,
  firmware_n TINYINT UNSIGNED NOT NULL,
  deviceId   VARCHAR(128) NULL,
  firmware   VARCHAR(128) NULL,

  longitude_n TINYINT UNSIGNED NOT NULL,
  latitude_n TINYINT UNSIGNED NOT NULL,

  longitude_mean DOUBLE NOT NULL,
  longitude_min  DOUBLE NOT NULL,
  longitude_max  DOUBLE NOT NULL,
  latitude_mean  DOUBLE NOT NULL,
  latitude_min   DOUBLE NOT NULL,
  latitude_max   DOUBLE NOT NULL,

  accuracy_mean DOUBLE NOT NULL,
  accuracy_min  DOUBLE NOT NULL,
  accuracy_max  DOUBLE NOT NULL,
  accuracy_n    TINYINT UNSIGNED NOT NULL,

  PRIMARY KEY (userId, bucket_5min),
  INDEX idx_gps_5min_bucket (bucket_5min),
  INDEX idx_gps_5min_source_created (source_created_at_max),

  CONSTRAINT chk_gps_5min_bucket_boundary
    CHECK (MOD(MINUTE(bucket_5min), 5) = 0
       AND SECOND(bucket_5min) = 0
       AND MICROSECOND(bucket_5min) = 0),
  CONSTRAINT chk_gps_5min_observed_minutes
    CHECK (observed_minute_n BETWEEN 1 AND 5),
  CONSTRAINT chk_gps_5min_provenance_counts
    CHECK (device_n BETWEEN 1 AND observed_minute_n
       AND firmware_n BETWEEN 1 AND observed_minute_n),
  CONSTRAINT chk_gps_5min_device_value
    CHECK ((device_n = 1 AND deviceId IS NOT NULL)
        OR (device_n > 1 AND deviceId IS NULL)),
  CONSTRAINT chk_gps_5min_firmware_value
    CHECK ((firmware_n = 1 AND firmware IS NOT NULL)
        OR (firmware_n > 1 AND firmware IS NULL)),
  CONSTRAINT chk_gps_5min_coordinate_counts
    CHECK (longitude_n = observed_minute_n AND latitude_n = observed_minute_n),
  CONSTRAINT chk_gps_5min_longitude
    CHECK (longitude_min BETWEEN -180 AND 180
       AND longitude_mean BETWEEN -180 AND 180
       AND longitude_max BETWEEN -180 AND 180
       AND longitude_min <= longitude_mean
       AND longitude_mean <= longitude_max),
  CONSTRAINT chk_gps_5min_latitude
    CHECK (latitude_min BETWEEN -90 AND 90
       AND latitude_mean BETWEEN -90 AND 90
       AND latitude_max BETWEEN -90 AND 90
       AND latitude_min <= latitude_mean
       AND latitude_mean <= latitude_max),
  CONSTRAINT chk_gps_5min_accuracy_count
    CHECK (accuracy_n = observed_minute_n),
  CONSTRAINT chk_gps_5min_accuracy_values
    CHECK (accuracy_min <= accuracy_mean AND accuracy_mean <= accuracy_max)
) ENGINE = InnoDB;

DELIMITER //

CREATE OR REPLACE PROCEDURE etl_gps_5min()
SQL SECURITY INVOKER
MODIFIES SQL DATA
main: BEGIN
  DECLARE v_started_at DATETIME(6);
  DECLARE v_finished_at DATETIME(6);
  DECLARE v_source_rows BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_source_buckets BIGINT UNSIGNED DEFAULT 0;
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

  SELECT COUNT(*)
  INTO v_source_rows
  FROM gps_tidy;

  IF v_source_rows = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'gps_tidy is empty; gps_5min was not rebuilt';
  END IF;

  SELECT COUNT(*)
  INTO v_source_buckets
  FROM (
    SELECT
      t.userId,
      t.bucket_5min
    FROM gps_tidy AS t
    GROUP BY
      t.userId,
      t.bucket_5min
  ) AS source_keys;

  DELETE FROM gps_5min;
  SET v_deleted_rows = ROW_COUNT();

  INSERT INTO gps_5min (
    userId,
    bucket_5min,
    source_created_at_max,
    observed_minute_n,
    device_n,
    firmware_n,
    deviceId,
    firmware,
    longitude_n,
    latitude_n,
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
    MAX(t.created_at) AS source_created_at_max,
    COUNT(DISTINCT t.minute_ts) AS observed_minute_n,
    COUNT(DISTINCT t.deviceId) AS device_n,
    COUNT(DISTINCT t.firmware) AS firmware_n,
    CASE
      WHEN COUNT(DISTINCT t.deviceId) = 1 THEN MIN(t.deviceId)
      ELSE NULL
    END AS deviceId,
    CASE
      WHEN COUNT(DISTINCT t.firmware) = 1 THEN MIN(t.firmware)
      ELSE NULL
    END AS firmware,
    COUNT(t.longitude) AS longitude_n,
    COUNT(t.latitude) AS latitude_n,
    AVG(t.longitude) AS longitude_mean,
    MIN(t.longitude) AS longitude_min,
    MAX(t.longitude) AS longitude_max,
    AVG(t.latitude) AS latitude_mean,
    MIN(t.latitude) AS latitude_min,
    MAX(t.latitude) AS latitude_max,
    AVG(t.accuracy) AS accuracy_mean,
    MIN(t.accuracy) AS accuracy_min,
    MAX(t.accuracy) AS accuracy_max,
    COUNT(t.accuracy) AS accuracy_n
  FROM gps_tidy AS t
  GROUP BY
    t.userId,
    t.bucket_5min;

  SET v_inserted_rows = ROW_COUNT();

  IF v_inserted_rows <> v_source_buckets THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'gps_5min output count differs from source bucket count';
  END IF;

  SELECT COUNT(*)
  INTO v_total_rows
  FROM gps_5min;

  IF v_total_rows <> v_source_buckets THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'gps_5min final count differs from source bucket count';
  END IF;

  COMMIT;

  SET v_finished_at = UTC_TIMESTAMP(6);

  SELECT
    'full' AS run_mode,
    v_started_at AS started_at,
    v_finished_at AS finished_at,
    v_source_rows AS source_rows,
    v_source_buckets AS source_buckets,
    v_deleted_rows AS deleted_5min_rows,
    v_inserted_rows AS inserted_5min_rows,
    v_total_rows AS total_5min_rows;
END//

DELIMITER ;
