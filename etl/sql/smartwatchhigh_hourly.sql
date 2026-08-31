-- ============================================================================
-- smartwatchhigh_hourly.sql
-- Source (read only): smartwatchhigh_5min. Grain: participant x UTC hour.
-- Continuous values are averaged across buckets; sleep-state codes are counted.
-- ============================================================================

CREATE TABLE IF NOT EXISTS smartwatchhigh_hourly (
  userId BIGINT NOT NULL,
  hour_ts DATETIME(6) NOT NULL,
  source_created_at_max DATETIME(6) NOT NULL,
  observed_5min_n TINYINT UNSIGNED NOT NULL,
  observed_minute_n TINYINT UNSIGNED NOT NULL,
  mixed_device_5min_n TINYINT UNSIGNED NOT NULL,
  mixed_firmware_5min_n TINYINT UNSIGNED NOT NULL,
  deviceId VARCHAR(128) NULL,
  firmware VARCHAR(128) NULL,

  heartrate_mean DOUBLE NULL, heartrate_min DOUBLE NULL, heartrate_max DOUBLE NULL,
  heartrate_5min_n TINYINT UNSIGNED NOT NULL, heartrate_minute_n TINYINT UNSIGNED NOT NULL,
  oxygens_mean DOUBLE NULL, oxygens_min DOUBLE NULL, oxygens_max DOUBLE NULL,
  oxygens_5min_n TINYINT UNSIGNED NOT NULL, oxygens_minute_n TINYINT UNSIGNED NOT NULL,
  breathrate_mean DOUBLE NULL, breathrate_min DOUBLE NULL, breathrate_max DOUBLE NULL,
  breathrate_5min_n TINYINT UNSIGNED NOT NULL, breathrate_minute_n TINYINT UNSIGNED NOT NULL,

  sleeprate_5min_n TINYINT UNSIGNED NOT NULL,      -- Buckets containing at least one valid code.
  sleeprate_minute_n TINYINT UNSIGNED NOT NULL,   -- All represented non-null state minutes.
  sleeprate_0_n TINYINT UNSIGNED NOT NULL,
  sleeprate_1_n TINYINT UNSIGNED NOT NULL,
  sleeprate_2_n TINYINT UNSIGNED NOT NULL,
  sleeprate_3_n TINYINT UNSIGNED NOT NULL,
  sleeprate_4_n TINYINT UNSIGNED NOT NULL,

  PRIMARY KEY (userId, hour_ts),
  INDEX idx_smartwatchhigh_hourly_hour (hour_ts),
  INDEX idx_smartwatchhigh_hourly_source_created (source_created_at_max),
  CONSTRAINT chk_smartwatchhigh_hourly_boundary
    CHECK (MINUTE(hour_ts) = 0 AND SECOND(hour_ts) = 0 AND MICROSECOND(hour_ts) = 0),
  CONSTRAINT chk_smartwatchhigh_hourly_coverage
    CHECK (observed_5min_n BETWEEN 1 AND 12
       AND observed_minute_n BETWEEN observed_5min_n AND 60),
  CONSTRAINT chk_smartwatchhigh_hourly_provenance
    CHECK (mixed_device_5min_n BETWEEN 0 AND observed_5min_n
       AND mixed_firmware_5min_n BETWEEN 0 AND observed_5min_n
       AND (deviceId IS NULL OR mixed_device_5min_n = 0)
       AND (firmware IS NULL OR mixed_firmware_5min_n = 0)),
  CONSTRAINT chk_smartwatchhigh_hourly_counts
    CHECK (heartrate_5min_n BETWEEN 0 AND observed_5min_n
       AND heartrate_minute_n BETWEEN heartrate_5min_n AND observed_minute_n
       AND oxygens_5min_n BETWEEN 0 AND observed_5min_n
       AND oxygens_minute_n BETWEEN oxygens_5min_n AND observed_minute_n
       AND breathrate_5min_n BETWEEN 0 AND observed_5min_n
       AND breathrate_minute_n BETWEEN breathrate_5min_n AND observed_minute_n
       AND sleeprate_5min_n BETWEEN 0 AND observed_5min_n
       AND sleeprate_minute_n BETWEEN sleeprate_5min_n AND observed_minute_n
       AND sleeprate_0_n + sleeprate_1_n + sleeprate_2_n
         + sleeprate_3_n + sleeprate_4_n = sleeprate_minute_n),
  CONSTRAINT chk_smartwatchhigh_hourly_continuous
    CHECK (((heartrate_5min_n = 0 AND heartrate_mean IS NULL AND heartrate_min IS NULL AND heartrate_max IS NULL)
         OR (heartrate_5min_n > 0 AND heartrate_mean IS NOT NULL AND heartrate_min > 0
           AND heartrate_min <= heartrate_mean AND heartrate_mean <= heartrate_max))
       AND ((oxygens_5min_n = 0 AND oxygens_mean IS NULL AND oxygens_min IS NULL AND oxygens_max IS NULL)
         OR (oxygens_5min_n > 0 AND oxygens_mean IS NOT NULL AND oxygens_min BETWEEN 1 AND 100
           AND oxygens_min <= oxygens_mean AND oxygens_mean <= oxygens_max AND oxygens_max <= 100))
       AND ((breathrate_5min_n = 0 AND breathrate_mean IS NULL AND breathrate_min IS NULL AND breathrate_max IS NULL)
         OR (breathrate_5min_n > 0 AND breathrate_mean IS NOT NULL AND breathrate_min BETWEEN 1 AND 100
           AND breathrate_min <= breathrate_mean AND breathrate_mean <= breathrate_max
           AND breathrate_max <= 100)))
) ENGINE = InnoDB;

DELIMITER //

CREATE OR REPLACE PROCEDURE etl_smartwatchhigh_hourly()
SQL SECURITY INVOKER
MODIFIES SQL DATA
main: BEGIN
  DECLARE v_started_at DATETIME(6);                 -- UTC procedure start time.
  DECLARE v_finished_at DATETIME(6);                -- UTC successful finish time.
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

  SET v_started_at = UTC_TIMESTAMP(6);
  START TRANSACTION WITH CONSISTENT SNAPSHOT;       -- Read one stable five-minute version.
  SELECT COUNT(*) INTO v_source_rows FROM smartwatchhigh_5min;
  IF v_source_rows = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'smartwatchhigh_5min is empty; smartwatchhigh_hourly was not rebuilt';
  END IF;
  SELECT COUNT(*) INTO v_source_hours
  FROM (
    SELECT userId, TIMESTAMP(DATE(bucket_5min), MAKETIME(HOUR(bucket_5min), 0, 0)) AS hour_ts
    FROM smartwatchhigh_5min GROUP BY userId, hour_ts
  ) AS source_keys;

  DELETE FROM smartwatchhigh_hourly;               -- Preserve the reviewed schema and indexes.
  SET v_deleted_rows = ROW_COUNT();
  INSERT INTO smartwatchhigh_hourly (
    userId, hour_ts, source_created_at_max, observed_5min_n, observed_minute_n,
    mixed_device_5min_n, mixed_firmware_5min_n, deviceId, firmware,
    heartrate_mean, heartrate_min, heartrate_max, heartrate_5min_n, heartrate_minute_n,
    oxygens_mean, oxygens_min, oxygens_max, oxygens_5min_n, oxygens_minute_n,
    breathrate_mean, breathrate_min, breathrate_max, breathrate_5min_n, breathrate_minute_n,
    sleeprate_5min_n, sleeprate_minute_n,
    sleeprate_0_n, sleeprate_1_n, sleeprate_2_n, sleeprate_3_n, sleeprate_4_n
  )
  SELECT
    f.userId, TIMESTAMP(DATE(f.bucket_5min), MAKETIME(HOUR(f.bucket_5min), 0, 0)),
    MAX(f.source_created_at_max), COUNT(*), SUM(f.observed_minute_n),
    SUM(f.device_n > 1), SUM(f.firmware_n > 1),
    CASE WHEN SUM(f.device_n > 1) = 0 AND COUNT(DISTINCT f.deviceId) = 1 THEN MIN(f.deviceId) END,
    CASE WHEN SUM(f.firmware_n > 1) = 0 AND COUNT(DISTINCT f.firmware) = 1 THEN MIN(f.firmware) END,
    AVG(f.heartrate_mean), MIN(f.heartrate_min), MAX(f.heartrate_max), COUNT(f.heartrate_mean), SUM(f.heartrate_n),
    AVG(f.oxygens_mean), MIN(f.oxygens_min), MAX(f.oxygens_max), COUNT(f.oxygens_mean), SUM(f.oxygens_n),
    AVG(f.breathrate_mean), MIN(f.breathrate_min), MAX(f.breathrate_max), COUNT(f.breathrate_mean), SUM(f.breathrate_n),
    SUM(f.sleeprate_n > 0), SUM(f.sleeprate_n),
    SUM(f.sleeprate_0_n), SUM(f.sleeprate_1_n), SUM(f.sleeprate_2_n),
    SUM(f.sleeprate_3_n), SUM(f.sleeprate_4_n)
  FROM smartwatchhigh_5min AS f
  GROUP BY f.userId, TIMESTAMP(DATE(f.bucket_5min), MAKETIME(HOUR(f.bucket_5min), 0, 0));

  SET v_inserted_rows = ROW_COUNT();
  IF v_inserted_rows <> v_source_hours THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'smartwatchhigh_hourly output count differs from source hour count';
  END IF;
  SELECT COUNT(*) INTO v_total_rows FROM smartwatchhigh_hourly;
  IF v_total_rows <> v_source_hours THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'smartwatchhigh_hourly final count differs from source hour count';
  END IF;
  COMMIT;                                          -- Publish only the complete replacement.
  SET v_finished_at = UTC_TIMESTAMP(6);
  SELECT 'full' AS run_mode, v_started_at AS started_at, v_finished_at AS finished_at,
    v_source_rows AS source_5min_rows, v_source_hours AS source_hours,
    v_deleted_rows AS deleted_hourly_rows, v_inserted_rows AS inserted_hourly_rows,
    v_total_rows AS total_hourly_rows;
END//

DELIMITER ;
