-- ============================================================================
-- myair_hourly.sql
-- Source (read only): myair_5min. Grain: participant x UTC hour.
-- Hourly means give equal weight to every available five-minute bucket.
-- ============================================================================

CREATE TABLE IF NOT EXISTS myair_hourly (
  userId BIGINT NOT NULL,
  hour_ts DATETIME(6) NOT NULL,
  source_created_at_max DATETIME(6) NOT NULL,
  observed_5min_n TINYINT UNSIGNED NOT NULL,
  observed_minute_n TINYINT UNSIGNED NOT NULL,
  mixed_device_5min_n TINYINT UNSIGNED NOT NULL,
  mixed_firmware_5min_n TINYINT UNSIGNED NOT NULL,
  deviceId VARCHAR(128) NULL,
  firmware VARCHAR(128) NULL,

  pm1_mean DOUBLE NULL, pm1_min DOUBLE NULL, pm1_max DOUBLE NULL,
  pm1_5min_n TINYINT UNSIGNED NOT NULL, pm1_minute_n TINYINT UNSIGNED NOT NULL,
  pm25_mean DOUBLE NULL, pm25_min DOUBLE NULL, pm25_max DOUBLE NULL,
  pm25_5min_n TINYINT UNSIGNED NOT NULL, pm25_minute_n TINYINT UNSIGNED NOT NULL,
  pm10_mean DOUBLE NULL, pm10_min DOUBLE NULL, pm10_max DOUBLE NULL,
  pm10_5min_n TINYINT UNSIGNED NOT NULL, pm10_minute_n TINYINT UNSIGNED NOT NULL,
  pc03_mean DOUBLE NULL, pc03_min DOUBLE NULL, pc03_max DOUBLE NULL,
  pc03_5min_n TINYINT UNSIGNED NOT NULL, pc03_minute_n TINYINT UNSIGNED NOT NULL,
  pc05_mean DOUBLE NULL, pc05_min DOUBLE NULL, pc05_max DOUBLE NULL,
  pc05_5min_n TINYINT UNSIGNED NOT NULL, pc05_minute_n TINYINT UNSIGNED NOT NULL,
  pc1_mean DOUBLE NULL, pc1_min DOUBLE NULL, pc1_max DOUBLE NULL,
  pc1_5min_n TINYINT UNSIGNED NOT NULL, pc1_minute_n TINYINT UNSIGNED NOT NULL,
  pc25_mean DOUBLE NULL, pc25_min DOUBLE NULL, pc25_max DOUBLE NULL,
  pc25_5min_n TINYINT UNSIGNED NOT NULL, pc25_minute_n TINYINT UNSIGNED NOT NULL,
  pc5_mean DOUBLE NULL, pc5_min DOUBLE NULL, pc5_max DOUBLE NULL,
  pc5_5min_n TINYINT UNSIGNED NOT NULL, pc5_minute_n TINYINT UNSIGNED NOT NULL,
  pc10_mean DOUBLE NULL, pc10_min DOUBLE NULL, pc10_max DOUBLE NULL,
  pc10_5min_n TINYINT UNSIGNED NOT NULL, pc10_minute_n TINYINT UNSIGNED NOT NULL,
  temperature_mean DOUBLE NULL, temperature_min DOUBLE NULL, temperature_max DOUBLE NULL,
  temperature_5min_n TINYINT UNSIGNED NOT NULL, temperature_minute_n TINYINT UNSIGNED NOT NULL,
  humidity_mean DOUBLE NULL, humidity_min DOUBLE NULL, humidity_max DOUBLE NULL,
  humidity_5min_n TINYINT UNSIGNED NOT NULL, humidity_minute_n TINYINT UNSIGNED NOT NULL,
  pressure_mean DOUBLE NULL, pressure_min DOUBLE NULL, pressure_max DOUBLE NULL,
  pressure_5min_n TINYINT UNSIGNED NOT NULL, pressure_minute_n TINYINT UNSIGNED NOT NULL,
  sound_mean DOUBLE NULL, sound_min DOUBLE NULL, sound_max DOUBLE NULL,
  sound_5min_n TINYINT UNSIGNED NOT NULL, sound_minute_n TINYINT UNSIGNED NOT NULL,
  uvb_mean DOUBLE NULL, uvb_min DOUBLE NULL, uvb_max DOUBLE NULL,
  uvb_5min_n TINYINT UNSIGNED NOT NULL, uvb_minute_n TINYINT UNSIGNED NOT NULL,
  light_mean DOUBLE NULL, light_min DOUBLE NULL, light_max DOUBLE NULL,
  light_5min_n TINYINT UNSIGNED NOT NULL, light_minute_n TINYINT UNSIGNED NOT NULL,

  PRIMARY KEY (userId, hour_ts),
  INDEX idx_myair_hourly_hour (hour_ts),
  INDEX idx_myair_hourly_source_created (source_created_at_max),
  CONSTRAINT chk_myair_hourly_boundary
    CHECK (MINUTE(hour_ts) = 0 AND SECOND(hour_ts) = 0 AND MICROSECOND(hour_ts) = 0),
  CONSTRAINT chk_myair_hourly_coverage
    CHECK (observed_5min_n BETWEEN 1 AND 12
       AND observed_minute_n BETWEEN observed_5min_n AND 60),
  CONSTRAINT chk_myair_hourly_provenance
    CHECK (mixed_device_5min_n BETWEEN 0 AND observed_5min_n
       AND mixed_firmware_5min_n BETWEEN 0 AND observed_5min_n
       AND (deviceId IS NULL OR mixed_device_5min_n = 0)
       AND (firmware IS NULL OR mixed_firmware_5min_n = 0)),
  CONSTRAINT chk_myair_hourly_counts
    CHECK (
      pm1_5min_n BETWEEN 0 AND observed_5min_n AND pm1_minute_n BETWEEN pm1_5min_n AND observed_minute_n
      AND pm25_5min_n BETWEEN 0 AND observed_5min_n AND pm25_minute_n BETWEEN pm25_5min_n AND observed_minute_n
      AND pm10_5min_n BETWEEN 0 AND observed_5min_n AND pm10_minute_n BETWEEN pm10_5min_n AND observed_minute_n
      AND pc03_5min_n BETWEEN 0 AND observed_5min_n AND pc03_minute_n BETWEEN pc03_5min_n AND observed_minute_n
      AND pc05_5min_n BETWEEN 0 AND observed_5min_n AND pc05_minute_n BETWEEN pc05_5min_n AND observed_minute_n
      AND pc1_5min_n BETWEEN 0 AND observed_5min_n AND pc1_minute_n BETWEEN pc1_5min_n AND observed_minute_n
      AND pc25_5min_n BETWEEN 0 AND observed_5min_n AND pc25_minute_n BETWEEN pc25_5min_n AND observed_minute_n
      AND pc5_5min_n BETWEEN 0 AND observed_5min_n AND pc5_minute_n BETWEEN pc5_5min_n AND observed_minute_n
      AND pc10_5min_n BETWEEN 0 AND observed_5min_n AND pc10_minute_n BETWEEN pc10_5min_n AND observed_minute_n
      AND temperature_5min_n BETWEEN 0 AND observed_5min_n AND temperature_minute_n BETWEEN temperature_5min_n AND observed_minute_n
      AND humidity_5min_n BETWEEN 0 AND observed_5min_n AND humidity_minute_n BETWEEN humidity_5min_n AND observed_minute_n
      AND pressure_5min_n BETWEEN 0 AND observed_5min_n AND pressure_minute_n BETWEEN pressure_5min_n AND observed_minute_n
      AND sound_5min_n BETWEEN 0 AND observed_5min_n AND sound_minute_n BETWEEN sound_5min_n AND observed_minute_n
      AND uvb_5min_n BETWEEN 0 AND observed_5min_n AND uvb_minute_n BETWEEN uvb_5min_n AND observed_minute_n
      AND light_5min_n BETWEEN 0 AND observed_5min_n AND light_minute_n BETWEEN light_5min_n AND observed_minute_n
    ),
  CONSTRAINT chk_myair_hourly_stats
    CHECK (
      ((pm1_5min_n = 0 AND pm1_mean IS NULL AND pm1_min IS NULL AND pm1_max IS NULL) OR (pm1_5min_n > 0 AND pm1_mean IS NOT NULL AND pm1_min <= pm1_mean AND pm1_mean <= pm1_max))
      AND ((pm25_5min_n = 0 AND pm25_mean IS NULL AND pm25_min IS NULL AND pm25_max IS NULL) OR (pm25_5min_n > 0 AND pm25_mean IS NOT NULL AND pm25_min <= pm25_mean AND pm25_mean <= pm25_max))
      AND ((pm10_5min_n = 0 AND pm10_mean IS NULL AND pm10_min IS NULL AND pm10_max IS NULL) OR (pm10_5min_n > 0 AND pm10_mean IS NOT NULL AND pm10_min <= pm10_mean AND pm10_mean <= pm10_max))
      AND ((pc03_5min_n = 0 AND pc03_mean IS NULL AND pc03_min IS NULL AND pc03_max IS NULL) OR (pc03_5min_n > 0 AND pc03_mean IS NOT NULL AND pc03_min <= pc03_mean AND pc03_mean <= pc03_max))
      AND ((pc05_5min_n = 0 AND pc05_mean IS NULL AND pc05_min IS NULL AND pc05_max IS NULL) OR (pc05_5min_n > 0 AND pc05_mean IS NOT NULL AND pc05_min <= pc05_mean AND pc05_mean <= pc05_max))
      AND ((pc1_5min_n = 0 AND pc1_mean IS NULL AND pc1_min IS NULL AND pc1_max IS NULL) OR (pc1_5min_n > 0 AND pc1_mean IS NOT NULL AND pc1_min <= pc1_mean AND pc1_mean <= pc1_max))
      AND ((pc25_5min_n = 0 AND pc25_mean IS NULL AND pc25_min IS NULL AND pc25_max IS NULL) OR (pc25_5min_n > 0 AND pc25_mean IS NOT NULL AND pc25_min <= pc25_mean AND pc25_mean <= pc25_max))
      AND ((pc5_5min_n = 0 AND pc5_mean IS NULL AND pc5_min IS NULL AND pc5_max IS NULL) OR (pc5_5min_n > 0 AND pc5_mean IS NOT NULL AND pc5_min <= pc5_mean AND pc5_mean <= pc5_max))
      AND ((pc10_5min_n = 0 AND pc10_mean IS NULL AND pc10_min IS NULL AND pc10_max IS NULL) OR (pc10_5min_n > 0 AND pc10_mean IS NOT NULL AND pc10_min <= pc10_mean AND pc10_mean <= pc10_max))
      AND ((temperature_5min_n = 0 AND temperature_mean IS NULL AND temperature_min IS NULL AND temperature_max IS NULL) OR (temperature_5min_n > 0 AND temperature_mean IS NOT NULL AND temperature_min <= temperature_mean AND temperature_mean <= temperature_max))
      AND ((humidity_5min_n = 0 AND humidity_mean IS NULL AND humidity_min IS NULL AND humidity_max IS NULL) OR (humidity_5min_n > 0 AND humidity_mean IS NOT NULL AND humidity_min <= humidity_mean AND humidity_mean <= humidity_max))
      AND ((pressure_5min_n = 0 AND pressure_mean IS NULL AND pressure_min IS NULL AND pressure_max IS NULL) OR (pressure_5min_n > 0 AND pressure_mean IS NOT NULL AND pressure_min <= pressure_mean AND pressure_mean <= pressure_max))
      AND ((sound_5min_n = 0 AND sound_mean IS NULL AND sound_min IS NULL AND sound_max IS NULL) OR (sound_5min_n > 0 AND sound_mean IS NOT NULL AND sound_min <= sound_mean AND sound_mean <= sound_max))
      AND ((uvb_5min_n = 0 AND uvb_mean IS NULL AND uvb_min IS NULL AND uvb_max IS NULL) OR (uvb_5min_n > 0 AND uvb_mean IS NOT NULL AND uvb_min <= uvb_mean AND uvb_mean <= uvb_max))
      AND ((light_5min_n = 0 AND light_mean IS NULL AND light_min IS NULL AND light_max IS NULL) OR (light_5min_n > 0 AND light_mean IS NOT NULL AND light_min <= light_mean AND light_mean <= light_max))
    )
) ENGINE = InnoDB;

DELIMITER //

CREATE OR REPLACE PROCEDURE etl_myair_hourly()
SQL SECURITY INVOKER
MODIFIES SQL DATA
main: BEGIN
  DECLARE v_started_at DATETIME(6);                -- UTC procedure start time.
  DECLARE v_finished_at DATETIME(6);               -- UTC successful finish time.
  DECLARE v_source_rows BIGINT UNSIGNED DEFAULT 0; -- Five-minute rows read.
  DECLARE v_source_hours BIGINT UNSIGNED DEFAULT 0;-- Expected participant-hours.
  DECLARE v_deleted_rows BIGINT UNSIGNED DEFAULT 0;-- Previous hourly rows removed.
  DECLARE v_inserted_rows BIGINT UNSIGNED DEFAULT 0;-- Replacement rows inserted.
  DECLARE v_total_rows BIGINT UNSIGNED DEFAULT 0;  -- Final hourly row count.
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;                                      -- Restore the preceding complete output.
    RESIGNAL;                                      -- Return the original SQL error.
  END;

  SET v_started_at = UTC_TIMESTAMP(6);             -- Record the beginning of this attempt.
  START TRANSACTION WITH CONSISTENT SNAPSHOT;       -- Read one stable five-minute version.
  SELECT COUNT(*) INTO v_source_rows FROM myair_5min;
  IF v_source_rows = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'myair_5min is empty; myair_hourly was not rebuilt';
  END IF;
  SELECT COUNT(*) INTO v_source_hours
  FROM (
    SELECT userId, TIMESTAMP(DATE(bucket_5min), MAKETIME(HOUR(bucket_5min), 0, 0)) AS hour_ts
    FROM myair_5min GROUP BY userId, hour_ts
  ) AS source_keys;

  DELETE FROM myair_hourly;                        -- Preserve the reviewed schema and indexes.
  SET v_deleted_rows = ROW_COUNT();                -- Capture the count before another statement.
  INSERT INTO myair_hourly (
    userId, hour_ts, source_created_at_max, observed_5min_n, observed_minute_n,
    mixed_device_5min_n, mixed_firmware_5min_n, deviceId, firmware,
    pm1_mean, pm1_min, pm1_max, pm1_5min_n, pm1_minute_n,
    pm25_mean, pm25_min, pm25_max, pm25_5min_n, pm25_minute_n,
    pm10_mean, pm10_min, pm10_max, pm10_5min_n, pm10_minute_n,
    pc03_mean, pc03_min, pc03_max, pc03_5min_n, pc03_minute_n,
    pc05_mean, pc05_min, pc05_max, pc05_5min_n, pc05_minute_n,
    pc1_mean, pc1_min, pc1_max, pc1_5min_n, pc1_minute_n,
    pc25_mean, pc25_min, pc25_max, pc25_5min_n, pc25_minute_n,
    pc5_mean, pc5_min, pc5_max, pc5_5min_n, pc5_minute_n,
    pc10_mean, pc10_min, pc10_max, pc10_5min_n, pc10_minute_n,
    temperature_mean, temperature_min, temperature_max, temperature_5min_n, temperature_minute_n,
    humidity_mean, humidity_min, humidity_max, humidity_5min_n, humidity_minute_n,
    pressure_mean, pressure_min, pressure_max, pressure_5min_n, pressure_minute_n,
    sound_mean, sound_min, sound_max, sound_5min_n, sound_minute_n,
    uvb_mean, uvb_min, uvb_max, uvb_5min_n, uvb_minute_n,
    light_mean, light_min, light_max, light_5min_n, light_minute_n
  )
  SELECT
    f.userId, TIMESTAMP(DATE(f.bucket_5min), MAKETIME(HOUR(f.bucket_5min), 0, 0)),
    MAX(f.source_created_at_max), COUNT(*), SUM(f.observed_minute_n),
    SUM(f.device_n > 1), SUM(f.firmware_n > 1),
    CASE WHEN SUM(f.device_n > 1) = 0 AND COUNT(DISTINCT f.deviceId) = 1 THEN MIN(f.deviceId) END,
    CASE WHEN SUM(f.firmware_n > 1) = 0 AND COUNT(DISTINCT f.firmware) = 1 THEN MIN(f.firmware) END,
    AVG(f.pm1_mean), MIN(f.pm1_min), MAX(f.pm1_max), COUNT(f.pm1_mean), SUM(f.pm1_n),
    AVG(f.pm25_mean), MIN(f.pm25_min), MAX(f.pm25_max), COUNT(f.pm25_mean), SUM(f.pm25_n),
    AVG(f.pm10_mean), MIN(f.pm10_min), MAX(f.pm10_max), COUNT(f.pm10_mean), SUM(f.pm10_n),
    AVG(f.pc03_mean), MIN(f.pc03_min), MAX(f.pc03_max), COUNT(f.pc03_mean), SUM(f.pc03_n),
    AVG(f.pc05_mean), MIN(f.pc05_min), MAX(f.pc05_max), COUNT(f.pc05_mean), SUM(f.pc05_n),
    AVG(f.pc1_mean), MIN(f.pc1_min), MAX(f.pc1_max), COUNT(f.pc1_mean), SUM(f.pc1_n),
    AVG(f.pc25_mean), MIN(f.pc25_min), MAX(f.pc25_max), COUNT(f.pc25_mean), SUM(f.pc25_n),
    AVG(f.pc5_mean), MIN(f.pc5_min), MAX(f.pc5_max), COUNT(f.pc5_mean), SUM(f.pc5_n),
    AVG(f.pc10_mean), MIN(f.pc10_min), MAX(f.pc10_max), COUNT(f.pc10_mean), SUM(f.pc10_n),
    AVG(f.temperature_mean), MIN(f.temperature_min), MAX(f.temperature_max), COUNT(f.temperature_mean), SUM(f.temperature_n),
    AVG(f.humidity_mean), MIN(f.humidity_min), MAX(f.humidity_max), COUNT(f.humidity_mean), SUM(f.humidity_n),
    AVG(f.pressure_mean), MIN(f.pressure_min), MAX(f.pressure_max), COUNT(f.pressure_mean), SUM(f.pressure_n),
    AVG(f.sound_mean), MIN(f.sound_min), MAX(f.sound_max), COUNT(f.sound_mean), SUM(f.sound_n),
    AVG(f.uvb_mean), MIN(f.uvb_min), MAX(f.uvb_max), COUNT(f.uvb_mean), SUM(f.uvb_n),
    AVG(f.light_mean), MIN(f.light_min), MAX(f.light_max), COUNT(f.light_mean), SUM(f.light_n)
  FROM myair_5min AS f
  GROUP BY f.userId, TIMESTAMP(DATE(f.bucket_5min), MAKETIME(HOUR(f.bucket_5min), 0, 0));

  SET v_inserted_rows = ROW_COUNT();
  IF v_inserted_rows <> v_source_hours THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'myair_hourly output count differs from source hour count';
  END IF;
  SELECT COUNT(*) INTO v_total_rows FROM myair_hourly;
  IF v_total_rows <> v_source_hours THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'myair_hourly final count differs from source hour count';
  END IF;
  COMMIT;                                          -- Publish only the complete replacement.
  SET v_finished_at = UTC_TIMESTAMP(6);
  SELECT 'full' AS run_mode, v_started_at AS started_at, v_finished_at AS finished_at,
    v_source_rows AS source_5min_rows, v_source_hours AS source_hours,
    v_deleted_rows AS deleted_hourly_rows, v_inserted_rows AS inserted_hourly_rows,
    v_total_rows AS total_hourly_rows;
END//

DELIMITER ;
