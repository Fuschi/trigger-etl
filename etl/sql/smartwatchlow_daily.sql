-- ============================================================================
-- smartwatchlow_daily.sql
-- Source (read only): smartwatchlow_hourly. Grain: participant x UTC calendar date.
-- Each daily mean gives equal weight to every available hourly mean.
-- Every JSON coverage profile has 24 entries ordered from hour 00 through 23.
-- ============================================================================

CREATE TABLE IF NOT EXISTS smartwatchlow_daily (
  userId BIGINT NOT NULL,
  date DATE NOT NULL,
  source_created_at_max DATETIME(6) NOT NULL,
  hours_n TINYINT UNSIGNED NOT NULL,
  five_min_n SMALLINT UNSIGNED NOT NULL,
  minute_n SMALLINT UNSIGNED NOT NULL,
  complete_hours_n TINYINT UNSIGNED NOT NULL,
  five_min_profile JSON NOT NULL,

  ambiguous_device_hour_n TINYINT UNSIGNED NOT NULL,
  ambiguous_firmware_hour_n TINYINT UNSIGNED NOT NULL,
  mixed_device_5min_n SMALLINT UNSIGNED NOT NULL,
  mixed_firmware_5min_n SMALLINT UNSIGNED NOT NULL,
  deviceId VARCHAR(128) NULL,
  firmware VARCHAR(128) NULL,

  step_mean DOUBLE NULL, step_min DOUBLE NULL, step_max DOUBLE NULL,
  step_hours_n TINYINT UNSIGNED NOT NULL,
  step_5min_n SMALLINT UNSIGNED NOT NULL,
  step_minute_n SMALLINT UNSIGNED NOT NULL,
  step_complete_hours_n TINYINT UNSIGNED NOT NULL,
  step_5min_profile JSON NOT NULL,

  cal_mean DOUBLE NULL, cal_min DOUBLE NULL, cal_max DOUBLE NULL,
  cal_hours_n TINYINT UNSIGNED NOT NULL,
  cal_5min_n SMALLINT UNSIGNED NOT NULL,
  cal_minute_n SMALLINT UNSIGNED NOT NULL,
  cal_complete_hours_n TINYINT UNSIGNED NOT NULL,
  cal_5min_profile JSON NOT NULL,

  bphigh_mean DOUBLE NULL, bphigh_min DOUBLE NULL, bphigh_max DOUBLE NULL,
  bphigh_hours_n TINYINT UNSIGNED NOT NULL,
  bphigh_5min_n SMALLINT UNSIGNED NOT NULL,
  bphigh_minute_n SMALLINT UNSIGNED NOT NULL,
  bphigh_complete_hours_n TINYINT UNSIGNED NOT NULL,
  bphigh_5min_profile JSON NOT NULL,

  bplow_mean DOUBLE NULL, bplow_min DOUBLE NULL, bplow_max DOUBLE NULL,
  bplow_hours_n TINYINT UNSIGNED NOT NULL,
  bplow_5min_n SMALLINT UNSIGNED NOT NULL,
  bplow_minute_n SMALLINT UNSIGNED NOT NULL,
  bplow_complete_hours_n TINYINT UNSIGNED NOT NULL,
  bplow_5min_profile JSON NOT NULL,

  bodytemp_mean DOUBLE NULL, bodytemp_min DOUBLE NULL, bodytemp_max DOUBLE NULL,
  bodytemp_hours_n TINYINT UNSIGNED NOT NULL,
  bodytemp_5min_n SMALLINT UNSIGNED NOT NULL,
  bodytemp_minute_n SMALLINT UNSIGNED NOT NULL,
  bodytemp_complete_hours_n TINYINT UNSIGNED NOT NULL,
  bodytemp_5min_profile JSON NOT NULL,

  skintemp_mean DOUBLE NULL, skintemp_min DOUBLE NULL, skintemp_max DOUBLE NULL,
  skintemp_hours_n TINYINT UNSIGNED NOT NULL,
  skintemp_5min_n SMALLINT UNSIGNED NOT NULL,
  skintemp_minute_n SMALLINT UNSIGNED NOT NULL,
  skintemp_complete_hours_n TINYINT UNSIGNED NOT NULL,
  skintemp_5min_profile JSON NOT NULL,

  PRIMARY KEY (userId, date),
  INDEX idx_smartwatchlow_daily_date (date),
  INDEX idx_smartwatchlow_daily_source_created (source_created_at_max),
  CONSTRAINT chk_smartwatchlow_daily_coverage
    CHECK (hours_n BETWEEN 1 AND 24
       AND five_min_n BETWEEN hours_n AND 288
       AND minute_n BETWEEN five_min_n AND 1440
       AND complete_hours_n BETWEEN 0 AND hours_n),
  CONSTRAINT chk_smartwatchlow_daily_profiles
    CHECK (JSON_VALID(five_min_profile) AND JSON_LENGTH(five_min_profile) = 24),
  CONSTRAINT chk_smartwatchlow_daily_provenance
    CHECK (ambiguous_device_hour_n BETWEEN 0 AND hours_n
       AND ambiguous_firmware_hour_n BETWEEN 0 AND hours_n
       AND mixed_device_5min_n BETWEEN 0 AND five_min_n
       AND mixed_firmware_5min_n BETWEEN 0 AND five_min_n
       AND (deviceId IS NULL OR ambiguous_device_hour_n = 0)
       AND (firmware IS NULL OR ambiguous_firmware_hour_n = 0)),
  CONSTRAINT chk_smartwatchlow_daily_measurement_counts
    CHECK (
      step_hours_n BETWEEN 0 AND hours_n
      AND step_5min_n BETWEEN step_hours_n AND five_min_n
      AND step_minute_n BETWEEN step_5min_n AND minute_n
      AND step_complete_hours_n BETWEEN 0 AND step_hours_n
      AND       cal_hours_n BETWEEN 0 AND hours_n
      AND cal_5min_n BETWEEN cal_hours_n AND five_min_n
      AND cal_minute_n BETWEEN cal_5min_n AND minute_n
      AND cal_complete_hours_n BETWEEN 0 AND cal_hours_n
      AND       bphigh_hours_n BETWEEN 0 AND hours_n
      AND bphigh_5min_n BETWEEN bphigh_hours_n AND five_min_n
      AND bphigh_minute_n BETWEEN bphigh_5min_n AND minute_n
      AND bphigh_complete_hours_n BETWEEN 0 AND bphigh_hours_n
      AND       bplow_hours_n BETWEEN 0 AND hours_n
      AND bplow_5min_n BETWEEN bplow_hours_n AND five_min_n
      AND bplow_minute_n BETWEEN bplow_5min_n AND minute_n
      AND bplow_complete_hours_n BETWEEN 0 AND bplow_hours_n
      AND       bodytemp_hours_n BETWEEN 0 AND hours_n
      AND bodytemp_5min_n BETWEEN bodytemp_hours_n AND five_min_n
      AND bodytemp_minute_n BETWEEN bodytemp_5min_n AND minute_n
      AND bodytemp_complete_hours_n BETWEEN 0 AND bodytemp_hours_n
      AND       skintemp_hours_n BETWEEN 0 AND hours_n
      AND skintemp_5min_n BETWEEN skintemp_hours_n AND five_min_n
      AND skintemp_minute_n BETWEEN skintemp_5min_n AND minute_n
      AND skintemp_complete_hours_n BETWEEN 0 AND skintemp_hours_n
    ),
  CONSTRAINT chk_smartwatchlow_daily_measurement_stats
    CHECK (
      ((step_hours_n = 0 AND step_mean IS NULL AND step_min IS NULL AND step_max IS NULL)
       OR (step_hours_n > 0 AND step_mean IS NOT NULL AND step_min IS NOT NULL
         AND step_max IS NOT NULL AND step_min <= step_mean AND step_mean <= step_max))
      AND       ((cal_hours_n = 0 AND cal_mean IS NULL AND cal_min IS NULL AND cal_max IS NULL)
       OR (cal_hours_n > 0 AND cal_mean IS NOT NULL AND cal_min IS NOT NULL
         AND cal_max IS NOT NULL AND cal_min <= cal_mean AND cal_mean <= cal_max))
      AND       ((bphigh_hours_n = 0 AND bphigh_mean IS NULL AND bphigh_min IS NULL AND bphigh_max IS NULL)
       OR (bphigh_hours_n > 0 AND bphigh_mean IS NOT NULL AND bphigh_min IS NOT NULL
         AND bphigh_max IS NOT NULL AND bphigh_min <= bphigh_mean AND bphigh_mean <= bphigh_max))
      AND       ((bplow_hours_n = 0 AND bplow_mean IS NULL AND bplow_min IS NULL AND bplow_max IS NULL)
       OR (bplow_hours_n > 0 AND bplow_mean IS NOT NULL AND bplow_min IS NOT NULL
         AND bplow_max IS NOT NULL AND bplow_min <= bplow_mean AND bplow_mean <= bplow_max))
      AND       ((bodytemp_hours_n = 0 AND bodytemp_mean IS NULL AND bodytemp_min IS NULL AND bodytemp_max IS NULL)
       OR (bodytemp_hours_n > 0 AND bodytemp_mean IS NOT NULL AND bodytemp_min IS NOT NULL
         AND bodytemp_max IS NOT NULL AND bodytemp_min <= bodytemp_mean AND bodytemp_mean <= bodytemp_max))
      AND       ((skintemp_hours_n = 0 AND skintemp_mean IS NULL AND skintemp_min IS NULL AND skintemp_max IS NULL)
       OR (skintemp_hours_n > 0 AND skintemp_mean IS NOT NULL AND skintemp_min IS NOT NULL
         AND skintemp_max IS NOT NULL AND skintemp_min <= skintemp_mean AND skintemp_mean <= skintemp_max))
    ),
  CONSTRAINT chk_smartwatchlow_daily_measurement_profiles
    CHECK (
      JSON_VALID(step_5min_profile) AND JSON_LENGTH(step_5min_profile) = 24
      AND JSON_VALID(cal_5min_profile) AND JSON_LENGTH(cal_5min_profile) = 24
      AND JSON_VALID(bphigh_5min_profile) AND JSON_LENGTH(bphigh_5min_profile) = 24
      AND JSON_VALID(bplow_5min_profile) AND JSON_LENGTH(bplow_5min_profile) = 24
      AND JSON_VALID(bodytemp_5min_profile) AND JSON_LENGTH(bodytemp_5min_profile) = 24
      AND JSON_VALID(skintemp_5min_profile) AND JSON_LENGTH(skintemp_5min_profile) = 24
    )
) ENGINE = InnoDB;

DELIMITER //

CREATE OR REPLACE PROCEDURE etl_smartwatchlow_daily()
SQL SECURITY INVOKER
MODIFIES SQL DATA
main: BEGIN
  DECLARE v_started_at DATETIME(6);                 -- UTC procedure start time.
  DECLARE v_finished_at DATETIME(6);                -- UTC successful finish time.
  DECLARE v_source_rows BIGINT UNSIGNED DEFAULT 0; -- Hourly rows read.
  DECLARE v_source_days BIGINT UNSIGNED DEFAULT 0; -- Expected participant-days.
  DECLARE v_deleted_rows BIGINT UNSIGNED DEFAULT 0;-- Previous daily rows removed.
  DECLARE v_inserted_rows BIGINT UNSIGNED DEFAULT 0;-- Replacement rows inserted.
  DECLARE v_total_rows BIGINT UNSIGNED DEFAULT 0;  -- Final daily row count.

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;                                      -- Restore the preceding complete daily table.
    RESIGNAL;                                      -- Return the original SQL error.
  END;

  SET v_started_at = UTC_TIMESTAMP(6);
  START TRANSACTION WITH CONSISTENT SNAPSHOT;       -- Read one stable hourly version.
  SELECT COUNT(*) INTO v_source_rows FROM smartwatchlow_hourly;
  IF v_source_rows = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'smartwatchlow_hourly is empty; smartwatchlow_daily was not rebuilt';
  END IF;

  SELECT COUNT(*) INTO v_source_days
  FROM (
    SELECT userId, DATE(hour_ts) AS date
    FROM smartwatchlow_hourly
    GROUP BY userId, DATE(hour_ts)
  ) AS source_keys;

  DELETE FROM smartwatchlow_daily;                     -- Preserve the reviewed schema and indexes.
  SET v_deleted_rows = ROW_COUNT();

  INSERT INTO smartwatchlow_daily (
    userId, date, source_created_at_max,
    hours_n, five_min_n, minute_n,
    complete_hours_n, five_min_profile,
    ambiguous_device_hour_n, ambiguous_firmware_hour_n,
    mixed_device_5min_n, mixed_firmware_5min_n, deviceId, firmware,
    step_mean, step_min, step_max, step_hours_n, step_5min_n,
    step_minute_n, step_complete_hours_n, step_5min_profile,
    cal_mean, cal_min, cal_max, cal_hours_n, cal_5min_n,
    cal_minute_n, cal_complete_hours_n, cal_5min_profile,
    bphigh_mean, bphigh_min, bphigh_max, bphigh_hours_n, bphigh_5min_n,
    bphigh_minute_n, bphigh_complete_hours_n, bphigh_5min_profile,
    bplow_mean, bplow_min, bplow_max, bplow_hours_n, bplow_5min_n,
    bplow_minute_n, bplow_complete_hours_n, bplow_5min_profile,
    bodytemp_mean, bodytemp_min, bodytemp_max, bodytemp_hours_n, bodytemp_5min_n,
    bodytemp_minute_n, bodytemp_complete_hours_n, bodytemp_5min_profile,
    skintemp_mean, skintemp_min, skintemp_max, skintemp_hours_n, skintemp_5min_n,
    skintemp_minute_n, skintemp_complete_hours_n, skintemp_5min_profile
  )
  WITH RECURSIVE hour_numbers AS (                 -- Materialize exactly the clock hours 00 through 23.
    SELECT 0 AS hour_n
    UNION ALL
    SELECT hour_n + 1 FROM hour_numbers WHERE hour_n < 23
  ),
  daily_keys AS (
    SELECT userId, DATE(hour_ts) AS date
    FROM smartwatchlow_hourly
    GROUP BY userId, DATE(hour_ts)
  ),
  hour_grid AS (                                   -- Add explicit zero-coverage rows for missing hours.
    SELECT
      k.userId,
      k.date,
      n.hour_n,
      h.hour_ts,
      h.source_created_at_max,
      h.observed_5min_n,
      h.observed_minute_n,
      h.mixed_device_5min_n,
      h.mixed_firmware_5min_n,
      h.deviceId,
      h.firmware,
      h.step_mean,
      h.step_min,
      h.step_max,
      h.step_5min_n,
      h.step_minute_n,
      h.cal_mean,
      h.cal_min,
      h.cal_max,
      h.cal_5min_n,
      h.cal_minute_n,
      h.bphigh_mean,
      h.bphigh_min,
      h.bphigh_max,
      h.bphigh_5min_n,
      h.bphigh_minute_n,
      h.bplow_mean,
      h.bplow_min,
      h.bplow_max,
      h.bplow_5min_n,
      h.bplow_minute_n,
      h.bodytemp_mean,
      h.bodytemp_min,
      h.bodytemp_max,
      h.bodytemp_5min_n,
      h.bodytemp_minute_n,
      h.skintemp_mean,
      h.skintemp_min,
      h.skintemp_max,
      h.skintemp_5min_n,
      h.skintemp_minute_n
    FROM daily_keys AS k
    CROSS JOIN hour_numbers AS n
    LEFT JOIN smartwatchlow_hourly AS h
      ON h.userId = k.userId
     AND h.hour_ts = TIMESTAMP(k.date, MAKETIME(n.hour_n, 0, 0))
  )
  SELECT
    g.userId,
    g.date,
    MAX(g.source_created_at_max),
    COUNT(g.hour_ts),
    COALESCE(SUM(g.observed_5min_n), 0),
    COALESCE(SUM(g.observed_minute_n), 0),
    COALESCE(SUM(g.observed_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.observed_5min_n, 0) ORDER BY g.hour_n),
    COALESCE(SUM(g.hour_ts IS NOT NULL AND g.deviceId IS NULL), 0),
    COALESCE(SUM(g.hour_ts IS NOT NULL AND g.firmware IS NULL), 0),
    COALESCE(SUM(g.mixed_device_5min_n), 0),
    COALESCE(SUM(g.mixed_firmware_5min_n), 0),
    CASE WHEN COUNT(g.hour_ts) = COUNT(g.deviceId)
           AND COUNT(DISTINCT g.deviceId) = 1 THEN MIN(g.deviceId) END,
    CASE WHEN COUNT(g.hour_ts) = COUNT(g.firmware)
           AND COUNT(DISTINCT g.firmware) = 1 THEN MIN(g.firmware) END,
    AVG(g.step_mean), MIN(g.step_min), MAX(g.step_max),
    COUNT(g.step_mean), COALESCE(SUM(g.step_5min_n), 0),
    COALESCE(SUM(g.step_minute_n), 0),
    COALESCE(SUM(g.step_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.step_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.cal_mean), MIN(g.cal_min), MAX(g.cal_max),
    COUNT(g.cal_mean), COALESCE(SUM(g.cal_5min_n), 0),
    COALESCE(SUM(g.cal_minute_n), 0),
    COALESCE(SUM(g.cal_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.cal_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.bphigh_mean), MIN(g.bphigh_min), MAX(g.bphigh_max),
    COUNT(g.bphigh_mean), COALESCE(SUM(g.bphigh_5min_n), 0),
    COALESCE(SUM(g.bphigh_minute_n), 0),
    COALESCE(SUM(g.bphigh_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.bphigh_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.bplow_mean), MIN(g.bplow_min), MAX(g.bplow_max),
    COUNT(g.bplow_mean), COALESCE(SUM(g.bplow_5min_n), 0),
    COALESCE(SUM(g.bplow_minute_n), 0),
    COALESCE(SUM(g.bplow_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.bplow_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.bodytemp_mean), MIN(g.bodytemp_min), MAX(g.bodytemp_max),
    COUNT(g.bodytemp_mean), COALESCE(SUM(g.bodytemp_5min_n), 0),
    COALESCE(SUM(g.bodytemp_minute_n), 0),
    COALESCE(SUM(g.bodytemp_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.bodytemp_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.skintemp_mean), MIN(g.skintemp_min), MAX(g.skintemp_max),
    COUNT(g.skintemp_mean), COALESCE(SUM(g.skintemp_5min_n), 0),
    COALESCE(SUM(g.skintemp_minute_n), 0),
    COALESCE(SUM(g.skintemp_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.skintemp_5min_n, 0) ORDER BY g.hour_n)
  FROM hour_grid AS g
  GROUP BY g.userId, g.date;

  SET v_inserted_rows = ROW_COUNT();
  IF v_inserted_rows <> v_source_days THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'smartwatchlow_daily output count differs from source day count';
  END IF;
  SELECT COUNT(*) INTO v_total_rows FROM smartwatchlow_daily;
  IF v_total_rows <> v_source_days THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'smartwatchlow_daily final count differs from source day count';
  END IF;

  COMMIT;                                          -- Publish only the complete replacement.
  SET v_finished_at = UTC_TIMESTAMP(6);
  SELECT 'full' AS run_mode, v_started_at AS started_at, v_finished_at AS finished_at,
    v_source_rows AS source_hourly_rows, v_source_days AS source_days,
    v_deleted_rows AS deleted_daily_rows, v_inserted_rows AS inserted_daily_rows,
    v_total_rows AS total_daily_rows;
END//

DELIMITER ;
