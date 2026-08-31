-- ============================================================================
-- smartwatchlow_hourly.sql
-- Source (read only): smartwatchlow_5min. Grain: participant x UTC hour.
-- Step and calorie values remain means because their sensor semantics are unresolved.
-- ============================================================================

CREATE TABLE IF NOT EXISTS smartwatchlow_hourly (
  userId BIGINT NOT NULL,
  hour_ts DATETIME(6) NOT NULL,
  source_created_at_max DATETIME(6) NOT NULL,
  observed_5min_n TINYINT UNSIGNED NOT NULL,
  observed_minute_n TINYINT UNSIGNED NOT NULL,
  mixed_device_5min_n TINYINT UNSIGNED NOT NULL,
  mixed_firmware_5min_n TINYINT UNSIGNED NOT NULL,
  deviceId VARCHAR(128) NULL,
  firmware VARCHAR(128) NULL,

  step_mean DOUBLE NULL, step_min DOUBLE NULL, step_max DOUBLE NULL,
  step_5min_n TINYINT UNSIGNED NOT NULL, step_minute_n TINYINT UNSIGNED NOT NULL,
  cal_mean DOUBLE NULL, cal_min DOUBLE NULL, cal_max DOUBLE NULL,
  cal_5min_n TINYINT UNSIGNED NOT NULL, cal_minute_n TINYINT UNSIGNED NOT NULL,
  bphigh_mean DOUBLE NULL, bphigh_min DOUBLE NULL, bphigh_max DOUBLE NULL,
  bphigh_5min_n TINYINT UNSIGNED NOT NULL, bphigh_minute_n TINYINT UNSIGNED NOT NULL,
  bplow_mean DOUBLE NULL, bplow_min DOUBLE NULL, bplow_max DOUBLE NULL,
  bplow_5min_n TINYINT UNSIGNED NOT NULL, bplow_minute_n TINYINT UNSIGNED NOT NULL,
  bodytemp_mean DOUBLE NULL, bodytemp_min DOUBLE NULL, bodytemp_max DOUBLE NULL,
  bodytemp_5min_n TINYINT UNSIGNED NOT NULL, bodytemp_minute_n TINYINT UNSIGNED NOT NULL,
  skintemp_mean DOUBLE NULL, skintemp_min DOUBLE NULL, skintemp_max DOUBLE NULL,
  skintemp_5min_n TINYINT UNSIGNED NOT NULL, skintemp_minute_n TINYINT UNSIGNED NOT NULL,

  PRIMARY KEY (userId, hour_ts),
  INDEX idx_smartwatchlow_hourly_hour (hour_ts),
  INDEX idx_smartwatchlow_hourly_source_created (source_created_at_max),
  CONSTRAINT chk_smartwatchlow_hourly_boundary
    CHECK (MINUTE(hour_ts) = 0 AND SECOND(hour_ts) = 0 AND MICROSECOND(hour_ts) = 0),
  CONSTRAINT chk_smartwatchlow_hourly_coverage
    CHECK (observed_5min_n BETWEEN 1 AND 12
       AND observed_minute_n BETWEEN observed_5min_n AND 60),
  CONSTRAINT chk_smartwatchlow_hourly_provenance
    CHECK (mixed_device_5min_n BETWEEN 0 AND observed_5min_n
       AND mixed_firmware_5min_n BETWEEN 0 AND observed_5min_n
       AND (deviceId IS NULL OR mixed_device_5min_n = 0)
       AND (firmware IS NULL OR mixed_firmware_5min_n = 0)),
  CONSTRAINT chk_smartwatchlow_hourly_counts
    CHECK (step_5min_n BETWEEN 0 AND observed_5min_n AND step_minute_n BETWEEN step_5min_n AND observed_minute_n
       AND cal_5min_n BETWEEN 0 AND observed_5min_n AND cal_minute_n BETWEEN cal_5min_n AND observed_minute_n
       AND bphigh_5min_n BETWEEN 0 AND observed_5min_n AND bphigh_minute_n BETWEEN bphigh_5min_n AND observed_minute_n
       AND bplow_5min_n = bphigh_5min_n AND bplow_minute_n = bphigh_minute_n
       AND bodytemp_5min_n BETWEEN 0 AND observed_5min_n AND bodytemp_minute_n BETWEEN bodytemp_5min_n AND observed_minute_n
       AND skintemp_5min_n BETWEEN 0 AND observed_5min_n AND skintemp_minute_n BETWEEN skintemp_5min_n AND observed_minute_n),
  CONSTRAINT chk_smartwatchlow_hourly_activity
    CHECK (((step_5min_n = 0 AND step_mean IS NULL AND step_min IS NULL AND step_max IS NULL)
         OR (step_5min_n > 0 AND step_mean IS NOT NULL AND step_min >= 0
             AND step_min <= step_mean AND step_mean <= step_max))
       AND ((cal_5min_n = 0 AND cal_mean IS NULL AND cal_min IS NULL AND cal_max IS NULL)
         OR (cal_5min_n > 0 AND cal_mean IS NOT NULL AND cal_min >= 0
             AND cal_min <= cal_mean AND cal_mean <= cal_max))),
  CONSTRAINT chk_smartwatchlow_hourly_pressure
    CHECK ((bphigh_5min_n = 0 AND bphigh_mean IS NULL AND bphigh_min IS NULL AND bphigh_max IS NULL
         AND bplow_mean IS NULL AND bplow_min IS NULL AND bplow_max IS NULL)
       OR (bphigh_5min_n > 0 AND bphigh_mean IS NOT NULL AND bplow_mean IS NOT NULL
         AND bphigh_min <= bphigh_mean AND bphigh_mean <= bphigh_max
         AND bplow_min <= bplow_mean AND bplow_mean <= bplow_max AND bphigh_mean >= bplow_mean)),
  CONSTRAINT chk_smartwatchlow_hourly_temperature
    CHECK (((bodytemp_5min_n = 0 AND bodytemp_mean IS NULL AND bodytemp_min IS NULL AND bodytemp_max IS NULL)
         OR (bodytemp_5min_n > 0 AND bodytemp_mean IS NOT NULL
           AND bodytemp_min <= bodytemp_mean AND bodytemp_mean <= bodytemp_max))
       AND ((skintemp_5min_n = 0 AND skintemp_mean IS NULL AND skintemp_min IS NULL AND skintemp_max IS NULL)
         OR (skintemp_5min_n > 0 AND skintemp_mean IS NOT NULL
           AND skintemp_min <= skintemp_mean AND skintemp_mean <= skintemp_max)))
) ENGINE = InnoDB;

DELIMITER //

CREATE OR REPLACE PROCEDURE etl_smartwatchlow_hourly()
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
  SELECT COUNT(*) INTO v_source_rows FROM smartwatchlow_5min;
  IF v_source_rows = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'smartwatchlow_5min is empty; smartwatchlow_hourly was not rebuilt';
  END IF;
  SELECT COUNT(*) INTO v_source_hours
  FROM (
    SELECT userId, TIMESTAMP(DATE(bucket_5min), MAKETIME(HOUR(bucket_5min), 0, 0)) AS hour_ts
    FROM smartwatchlow_5min GROUP BY userId, hour_ts
  ) AS source_keys;

  DELETE FROM smartwatchlow_hourly;                -- Preserve the reviewed schema and indexes.
  SET v_deleted_rows = ROW_COUNT();
  INSERT INTO smartwatchlow_hourly (
    userId, hour_ts, source_created_at_max, observed_5min_n, observed_minute_n,
    mixed_device_5min_n, mixed_firmware_5min_n, deviceId, firmware,
    step_mean, step_min, step_max, step_5min_n, step_minute_n,
    cal_mean, cal_min, cal_max, cal_5min_n, cal_minute_n,
    bphigh_mean, bphigh_min, bphigh_max, bphigh_5min_n, bphigh_minute_n,
    bplow_mean, bplow_min, bplow_max, bplow_5min_n, bplow_minute_n,
    bodytemp_mean, bodytemp_min, bodytemp_max, bodytemp_5min_n, bodytemp_minute_n,
    skintemp_mean, skintemp_min, skintemp_max, skintemp_5min_n, skintemp_minute_n
  )
  SELECT
    f.userId, TIMESTAMP(DATE(f.bucket_5min), MAKETIME(HOUR(f.bucket_5min), 0, 0)),
    MAX(f.source_created_at_max), COUNT(*), SUM(f.observed_minute_n),
    SUM(f.device_n > 1), SUM(f.firmware_n > 1),
    CASE WHEN SUM(f.device_n > 1) = 0 AND COUNT(DISTINCT f.deviceId) = 1 THEN MIN(f.deviceId) END,
    CASE WHEN SUM(f.firmware_n > 1) = 0 AND COUNT(DISTINCT f.firmware) = 1 THEN MIN(f.firmware) END,
    AVG(f.step_mean), MIN(f.step_min), MAX(f.step_max), COUNT(f.step_mean), SUM(f.step_n),
    AVG(f.cal_mean), MIN(f.cal_min), MAX(f.cal_max), COUNT(f.cal_mean), SUM(f.cal_n),
    AVG(f.bphigh_mean), MIN(f.bphigh_min), MAX(f.bphigh_max), COUNT(f.bphigh_mean), SUM(f.bphigh_n),
    AVG(f.bplow_mean), MIN(f.bplow_min), MAX(f.bplow_max), COUNT(f.bplow_mean), SUM(f.bplow_n),
    AVG(f.bodytemp_mean), MIN(f.bodytemp_min), MAX(f.bodytemp_max), COUNT(f.bodytemp_mean), SUM(f.bodytemp_n),
    AVG(f.skintemp_mean), MIN(f.skintemp_min), MAX(f.skintemp_max), COUNT(f.skintemp_mean), SUM(f.skintemp_n)
  FROM smartwatchlow_5min AS f
  GROUP BY f.userId, TIMESTAMP(DATE(f.bucket_5min), MAKETIME(HOUR(f.bucket_5min), 0, 0));

  SET v_inserted_rows = ROW_COUNT();
  IF v_inserted_rows <> v_source_hours THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'smartwatchlow_hourly output count differs from source hour count';
  END IF;
  SELECT COUNT(*) INTO v_total_rows FROM smartwatchlow_hourly;
  IF v_total_rows <> v_source_hours THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'smartwatchlow_hourly final count differs from source hour count';
  END IF;
  COMMIT;                                          -- Publish only the complete replacement.
  SET v_finished_at = UTC_TIMESTAMP(6);
  SELECT 'full' AS run_mode, v_started_at AS started_at, v_finished_at AS finished_at,
    v_source_rows AS source_5min_rows, v_source_hours AS source_hours,
    v_deleted_rows AS deleted_hourly_rows, v_inserted_rows AS inserted_hourly_rows,
    v_total_rows AS total_hourly_rows;
END//

DELIMITER ;
