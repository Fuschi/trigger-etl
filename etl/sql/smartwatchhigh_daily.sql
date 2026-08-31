-- ============================================================================
-- smartwatchhigh_daily.sql
-- Source (read only): smartwatchhigh_hourly. Grain: participant x UTC calendar date.
-- Each daily mean gives equal weight to every available hourly mean.
-- Every JSON coverage profile has 24 entries ordered from hour 00 through 23.
-- ============================================================================

CREATE TABLE IF NOT EXISTS smartwatchhigh_daily (
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

  heartrate_mean DOUBLE NULL, heartrate_min DOUBLE NULL, heartrate_max DOUBLE NULL,
  heartrate_hours_n TINYINT UNSIGNED NOT NULL,
  heartrate_5min_n SMALLINT UNSIGNED NOT NULL,
  heartrate_minute_n SMALLINT UNSIGNED NOT NULL,
  heartrate_complete_hours_n TINYINT UNSIGNED NOT NULL,
  heartrate_5min_profile JSON NOT NULL,

  oxygens_mean DOUBLE NULL, oxygens_min DOUBLE NULL, oxygens_max DOUBLE NULL,
  oxygens_hours_n TINYINT UNSIGNED NOT NULL,
  oxygens_5min_n SMALLINT UNSIGNED NOT NULL,
  oxygens_minute_n SMALLINT UNSIGNED NOT NULL,
  oxygens_complete_hours_n TINYINT UNSIGNED NOT NULL,
  oxygens_5min_profile JSON NOT NULL,

  breathrate_mean DOUBLE NULL, breathrate_min DOUBLE NULL, breathrate_max DOUBLE NULL,
  breathrate_hours_n TINYINT UNSIGNED NOT NULL,
  breathrate_5min_n SMALLINT UNSIGNED NOT NULL,
  breathrate_minute_n SMALLINT UNSIGNED NOT NULL,
  breathrate_complete_hours_n TINYINT UNSIGNED NOT NULL,
  breathrate_5min_profile JSON NOT NULL,

  sleeprate_hours_n TINYINT UNSIGNED NOT NULL,
  sleeprate_5min_n SMALLINT UNSIGNED NOT NULL,
  sleeprate_minute_n SMALLINT UNSIGNED NOT NULL,
  sleeprate_complete_hours_n TINYINT UNSIGNED NOT NULL,
  sleeprate_5min_profile JSON NOT NULL,
  sleeprate_0_n SMALLINT UNSIGNED NOT NULL,
  sleeprate_1_n SMALLINT UNSIGNED NOT NULL,
  sleeprate_2_n SMALLINT UNSIGNED NOT NULL,
  sleeprate_3_n SMALLINT UNSIGNED NOT NULL,
  sleeprate_4_n SMALLINT UNSIGNED NOT NULL,

  PRIMARY KEY (userId, date),
  INDEX idx_smartwatchhigh_daily_date (date),
  INDEX idx_smartwatchhigh_daily_source_created (source_created_at_max),
  CONSTRAINT chk_smartwatchhigh_daily_coverage
    CHECK (hours_n BETWEEN 1 AND 24
       AND five_min_n BETWEEN hours_n AND 288
       AND minute_n BETWEEN five_min_n AND 1440
       AND complete_hours_n BETWEEN 0 AND hours_n),
  CONSTRAINT chk_smartwatchhigh_daily_profiles
    CHECK (JSON_VALID(five_min_profile) AND JSON_LENGTH(five_min_profile) = 24),
  CONSTRAINT chk_smartwatchhigh_daily_provenance
    CHECK (ambiguous_device_hour_n BETWEEN 0 AND hours_n
       AND ambiguous_firmware_hour_n BETWEEN 0 AND hours_n
       AND mixed_device_5min_n BETWEEN 0 AND five_min_n
       AND mixed_firmware_5min_n BETWEEN 0 AND five_min_n
       AND (deviceId IS NULL OR ambiguous_device_hour_n = 0)
       AND (firmware IS NULL OR ambiguous_firmware_hour_n = 0)),
  CONSTRAINT chk_smartwatchhigh_daily_measurement_counts
    CHECK (
      heartrate_hours_n BETWEEN 0 AND hours_n
      AND heartrate_5min_n BETWEEN heartrate_hours_n AND five_min_n
      AND heartrate_minute_n BETWEEN heartrate_5min_n AND minute_n
      AND heartrate_complete_hours_n BETWEEN 0 AND heartrate_hours_n
      AND       oxygens_hours_n BETWEEN 0 AND hours_n
      AND oxygens_5min_n BETWEEN oxygens_hours_n AND five_min_n
      AND oxygens_minute_n BETWEEN oxygens_5min_n AND minute_n
      AND oxygens_complete_hours_n BETWEEN 0 AND oxygens_hours_n
      AND       breathrate_hours_n BETWEEN 0 AND hours_n
      AND breathrate_5min_n BETWEEN breathrate_hours_n AND five_min_n
      AND breathrate_minute_n BETWEEN breathrate_5min_n AND minute_n
      AND breathrate_complete_hours_n BETWEEN 0 AND breathrate_hours_n
    ),
  CONSTRAINT chk_smartwatchhigh_daily_measurement_stats
    CHECK (
      ((heartrate_hours_n = 0 AND heartrate_mean IS NULL AND heartrate_min IS NULL AND heartrate_max IS NULL)
       OR (heartrate_hours_n > 0 AND heartrate_mean IS NOT NULL AND heartrate_min IS NOT NULL
         AND heartrate_max IS NOT NULL AND heartrate_min <= heartrate_mean AND heartrate_mean <= heartrate_max))
      AND       ((oxygens_hours_n = 0 AND oxygens_mean IS NULL AND oxygens_min IS NULL AND oxygens_max IS NULL)
       OR (oxygens_hours_n > 0 AND oxygens_mean IS NOT NULL AND oxygens_min IS NOT NULL
         AND oxygens_max IS NOT NULL AND oxygens_min <= oxygens_mean AND oxygens_mean <= oxygens_max))
      AND       ((breathrate_hours_n = 0 AND breathrate_mean IS NULL AND breathrate_min IS NULL AND breathrate_max IS NULL)
       OR (breathrate_hours_n > 0 AND breathrate_mean IS NOT NULL AND breathrate_min IS NOT NULL
         AND breathrate_max IS NOT NULL AND breathrate_min <= breathrate_mean AND breathrate_mean <= breathrate_max))
    ),
  CONSTRAINT chk_smartwatchhigh_daily_measurement_profiles
    CHECK (
      JSON_VALID(heartrate_5min_profile) AND JSON_LENGTH(heartrate_5min_profile) = 24
      AND JSON_VALID(oxygens_5min_profile) AND JSON_LENGTH(oxygens_5min_profile) = 24
      AND JSON_VALID(breathrate_5min_profile) AND JSON_LENGTH(breathrate_5min_profile) = 24
    ),
  CONSTRAINT chk_smartwatchhigh_daily_sleeprate
    CHECK (sleeprate_hours_n BETWEEN 0 AND hours_n
       AND sleeprate_5min_n BETWEEN sleeprate_hours_n AND five_min_n
       AND sleeprate_minute_n BETWEEN sleeprate_5min_n AND minute_n
       AND sleeprate_complete_hours_n BETWEEN 0 AND sleeprate_hours_n
       AND sleeprate_0_n + sleeprate_1_n + sleeprate_2_n
         + sleeprate_3_n + sleeprate_4_n = sleeprate_minute_n
       AND JSON_VALID(sleeprate_5min_profile)
       AND JSON_LENGTH(sleeprate_5min_profile) = 24)
) ENGINE = InnoDB;

DELIMITER //

CREATE OR REPLACE PROCEDURE etl_smartwatchhigh_daily()
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
  SELECT COUNT(*) INTO v_source_rows FROM smartwatchhigh_hourly;
  IF v_source_rows = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'smartwatchhigh_hourly is empty; smartwatchhigh_daily was not rebuilt';
  END IF;

  SELECT COUNT(*) INTO v_source_days
  FROM (
    SELECT userId, DATE(hour_ts) AS date
    FROM smartwatchhigh_hourly
    GROUP BY userId, DATE(hour_ts)
  ) AS source_keys;

  DELETE FROM smartwatchhigh_daily;                     -- Preserve the reviewed schema and indexes.
  SET v_deleted_rows = ROW_COUNT();

  INSERT INTO smartwatchhigh_daily (
    userId, date, source_created_at_max,
    hours_n, five_min_n, minute_n,
    complete_hours_n, five_min_profile,
    ambiguous_device_hour_n, ambiguous_firmware_hour_n,
    mixed_device_5min_n, mixed_firmware_5min_n, deviceId, firmware,
    heartrate_mean, heartrate_min, heartrate_max, heartrate_hours_n, heartrate_5min_n,
    heartrate_minute_n, heartrate_complete_hours_n, heartrate_5min_profile,
    oxygens_mean, oxygens_min, oxygens_max, oxygens_hours_n, oxygens_5min_n,
    oxygens_minute_n, oxygens_complete_hours_n, oxygens_5min_profile,
    breathrate_mean, breathrate_min, breathrate_max, breathrate_hours_n, breathrate_5min_n,
    breathrate_minute_n, breathrate_complete_hours_n, breathrate_5min_profile,
    sleeprate_hours_n, sleeprate_5min_n, sleeprate_minute_n,
    sleeprate_complete_hours_n, sleeprate_5min_profile,
    sleeprate_0_n, sleeprate_1_n, sleeprate_2_n, sleeprate_3_n, sleeprate_4_n
  )
  WITH RECURSIVE hour_numbers AS (                 -- Materialize exactly the clock hours 00 through 23.
    SELECT 0 AS hour_n
    UNION ALL
    SELECT hour_n + 1 FROM hour_numbers WHERE hour_n < 23
  ),
  daily_keys AS (
    SELECT userId, DATE(hour_ts) AS date
    FROM smartwatchhigh_hourly
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
      h.heartrate_mean,
      h.heartrate_min,
      h.heartrate_max,
      h.heartrate_5min_n,
      h.heartrate_minute_n,
      h.oxygens_mean,
      h.oxygens_min,
      h.oxygens_max,
      h.oxygens_5min_n,
      h.oxygens_minute_n,
      h.breathrate_mean,
      h.breathrate_min,
      h.breathrate_max,
      h.breathrate_5min_n,
      h.breathrate_minute_n,
      h.sleeprate_5min_n,
      h.sleeprate_minute_n,
      h.sleeprate_0_n,
      h.sleeprate_1_n,
      h.sleeprate_2_n,
      h.sleeprate_3_n,
      h.sleeprate_4_n
    FROM daily_keys AS k
    CROSS JOIN hour_numbers AS n
    LEFT JOIN smartwatchhigh_hourly AS h
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
    AVG(g.heartrate_mean), MIN(g.heartrate_min), MAX(g.heartrate_max),
    COUNT(g.heartrate_mean), COALESCE(SUM(g.heartrate_5min_n), 0),
    COALESCE(SUM(g.heartrate_minute_n), 0),
    COALESCE(SUM(g.heartrate_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.heartrate_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.oxygens_mean), MIN(g.oxygens_min), MAX(g.oxygens_max),
    COUNT(g.oxygens_mean), COALESCE(SUM(g.oxygens_5min_n), 0),
    COALESCE(SUM(g.oxygens_minute_n), 0),
    COALESCE(SUM(g.oxygens_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.oxygens_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.breathrate_mean), MIN(g.breathrate_min), MAX(g.breathrate_max),
    COUNT(g.breathrate_mean), COALESCE(SUM(g.breathrate_5min_n), 0),
    COALESCE(SUM(g.breathrate_minute_n), 0),
    COALESCE(SUM(g.breathrate_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.breathrate_5min_n, 0) ORDER BY g.hour_n),
    COALESCE(SUM(g.sleeprate_5min_n > 0), 0), COALESCE(SUM(g.sleeprate_5min_n), 0),
    COALESCE(SUM(g.sleeprate_minute_n), 0), COALESCE(SUM(g.sleeprate_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.sleeprate_5min_n, 0) ORDER BY g.hour_n),
    COALESCE(SUM(g.sleeprate_0_n), 0), COALESCE(SUM(g.sleeprate_1_n), 0),
    COALESCE(SUM(g.sleeprate_2_n), 0), COALESCE(SUM(g.sleeprate_3_n), 0),
    COALESCE(SUM(g.sleeprate_4_n), 0)
  FROM hour_grid AS g
  GROUP BY g.userId, g.date;

  SET v_inserted_rows = ROW_COUNT();
  IF v_inserted_rows <> v_source_days THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'smartwatchhigh_daily output count differs from source day count';
  END IF;
  SELECT COUNT(*) INTO v_total_rows FROM smartwatchhigh_daily;
  IF v_total_rows <> v_source_days THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'smartwatchhigh_daily final count differs from source day count';
  END IF;

  COMMIT;                                          -- Publish only the complete replacement.
  SET v_finished_at = UTC_TIMESTAMP(6);
  SELECT 'full' AS run_mode, v_started_at AS started_at, v_finished_at AS finished_at,
    v_source_rows AS source_hourly_rows, v_source_days AS source_days,
    v_deleted_rows AS deleted_daily_rows, v_inserted_rows AS inserted_daily_rows,
    v_total_rows AS total_daily_rows;
END//

DELIMITER ;
