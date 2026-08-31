-- ============================================================================
-- myair_daily.sql
-- Source (read only): myair_hourly. Grain: participant x UTC calendar date.
-- Each daily mean gives equal weight to every available hourly mean.
-- Every JSON coverage profile has 24 entries ordered from hour 00 through 23.
-- ============================================================================

CREATE TABLE IF NOT EXISTS myair_daily (
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

  pm1_mean DOUBLE NULL, pm1_min DOUBLE NULL, pm1_max DOUBLE NULL,
  pm1_hours_n TINYINT UNSIGNED NOT NULL,
  pm1_5min_n SMALLINT UNSIGNED NOT NULL,
  pm1_minute_n SMALLINT UNSIGNED NOT NULL,
  pm1_complete_hours_n TINYINT UNSIGNED NOT NULL,
  pm1_5min_profile JSON NOT NULL,

  pm25_mean DOUBLE NULL, pm25_min DOUBLE NULL, pm25_max DOUBLE NULL,
  pm25_hours_n TINYINT UNSIGNED NOT NULL,
  pm25_5min_n SMALLINT UNSIGNED NOT NULL,
  pm25_minute_n SMALLINT UNSIGNED NOT NULL,
  pm25_complete_hours_n TINYINT UNSIGNED NOT NULL,
  pm25_5min_profile JSON NOT NULL,

  pm10_mean DOUBLE NULL, pm10_min DOUBLE NULL, pm10_max DOUBLE NULL,
  pm10_hours_n TINYINT UNSIGNED NOT NULL,
  pm10_5min_n SMALLINT UNSIGNED NOT NULL,
  pm10_minute_n SMALLINT UNSIGNED NOT NULL,
  pm10_complete_hours_n TINYINT UNSIGNED NOT NULL,
  pm10_5min_profile JSON NOT NULL,

  pc03_mean DOUBLE NULL, pc03_min DOUBLE NULL, pc03_max DOUBLE NULL,
  pc03_hours_n TINYINT UNSIGNED NOT NULL,
  pc03_5min_n SMALLINT UNSIGNED NOT NULL,
  pc03_minute_n SMALLINT UNSIGNED NOT NULL,
  pc03_complete_hours_n TINYINT UNSIGNED NOT NULL,
  pc03_5min_profile JSON NOT NULL,

  pc05_mean DOUBLE NULL, pc05_min DOUBLE NULL, pc05_max DOUBLE NULL,
  pc05_hours_n TINYINT UNSIGNED NOT NULL,
  pc05_5min_n SMALLINT UNSIGNED NOT NULL,
  pc05_minute_n SMALLINT UNSIGNED NOT NULL,
  pc05_complete_hours_n TINYINT UNSIGNED NOT NULL,
  pc05_5min_profile JSON NOT NULL,

  pc1_mean DOUBLE NULL, pc1_min DOUBLE NULL, pc1_max DOUBLE NULL,
  pc1_hours_n TINYINT UNSIGNED NOT NULL,
  pc1_5min_n SMALLINT UNSIGNED NOT NULL,
  pc1_minute_n SMALLINT UNSIGNED NOT NULL,
  pc1_complete_hours_n TINYINT UNSIGNED NOT NULL,
  pc1_5min_profile JSON NOT NULL,

  pc25_mean DOUBLE NULL, pc25_min DOUBLE NULL, pc25_max DOUBLE NULL,
  pc25_hours_n TINYINT UNSIGNED NOT NULL,
  pc25_5min_n SMALLINT UNSIGNED NOT NULL,
  pc25_minute_n SMALLINT UNSIGNED NOT NULL,
  pc25_complete_hours_n TINYINT UNSIGNED NOT NULL,
  pc25_5min_profile JSON NOT NULL,

  pc5_mean DOUBLE NULL, pc5_min DOUBLE NULL, pc5_max DOUBLE NULL,
  pc5_hours_n TINYINT UNSIGNED NOT NULL,
  pc5_5min_n SMALLINT UNSIGNED NOT NULL,
  pc5_minute_n SMALLINT UNSIGNED NOT NULL,
  pc5_complete_hours_n TINYINT UNSIGNED NOT NULL,
  pc5_5min_profile JSON NOT NULL,

  pc10_mean DOUBLE NULL, pc10_min DOUBLE NULL, pc10_max DOUBLE NULL,
  pc10_hours_n TINYINT UNSIGNED NOT NULL,
  pc10_5min_n SMALLINT UNSIGNED NOT NULL,
  pc10_minute_n SMALLINT UNSIGNED NOT NULL,
  pc10_complete_hours_n TINYINT UNSIGNED NOT NULL,
  pc10_5min_profile JSON NOT NULL,

  temperature_mean DOUBLE NULL, temperature_min DOUBLE NULL, temperature_max DOUBLE NULL,
  temperature_hours_n TINYINT UNSIGNED NOT NULL,
  temperature_5min_n SMALLINT UNSIGNED NOT NULL,
  temperature_minute_n SMALLINT UNSIGNED NOT NULL,
  temperature_complete_hours_n TINYINT UNSIGNED NOT NULL,
  temperature_5min_profile JSON NOT NULL,

  humidity_mean DOUBLE NULL, humidity_min DOUBLE NULL, humidity_max DOUBLE NULL,
  humidity_hours_n TINYINT UNSIGNED NOT NULL,
  humidity_5min_n SMALLINT UNSIGNED NOT NULL,
  humidity_minute_n SMALLINT UNSIGNED NOT NULL,
  humidity_complete_hours_n TINYINT UNSIGNED NOT NULL,
  humidity_5min_profile JSON NOT NULL,

  pressure_mean DOUBLE NULL, pressure_min DOUBLE NULL, pressure_max DOUBLE NULL,
  pressure_hours_n TINYINT UNSIGNED NOT NULL,
  pressure_5min_n SMALLINT UNSIGNED NOT NULL,
  pressure_minute_n SMALLINT UNSIGNED NOT NULL,
  pressure_complete_hours_n TINYINT UNSIGNED NOT NULL,
  pressure_5min_profile JSON NOT NULL,

  sound_mean DOUBLE NULL, sound_min DOUBLE NULL, sound_max DOUBLE NULL,
  sound_hours_n TINYINT UNSIGNED NOT NULL,
  sound_5min_n SMALLINT UNSIGNED NOT NULL,
  sound_minute_n SMALLINT UNSIGNED NOT NULL,
  sound_complete_hours_n TINYINT UNSIGNED NOT NULL,
  sound_5min_profile JSON NOT NULL,

  uvb_mean DOUBLE NULL, uvb_min DOUBLE NULL, uvb_max DOUBLE NULL,
  uvb_hours_n TINYINT UNSIGNED NOT NULL,
  uvb_5min_n SMALLINT UNSIGNED NOT NULL,
  uvb_minute_n SMALLINT UNSIGNED NOT NULL,
  uvb_complete_hours_n TINYINT UNSIGNED NOT NULL,
  uvb_5min_profile JSON NOT NULL,

  light_mean DOUBLE NULL, light_min DOUBLE NULL, light_max DOUBLE NULL,
  light_hours_n TINYINT UNSIGNED NOT NULL,
  light_5min_n SMALLINT UNSIGNED NOT NULL,
  light_minute_n SMALLINT UNSIGNED NOT NULL,
  light_complete_hours_n TINYINT UNSIGNED NOT NULL,
  light_5min_profile JSON NOT NULL,

  PRIMARY KEY (userId, date),
  INDEX idx_myair_daily_date (date),
  INDEX idx_myair_daily_source_created (source_created_at_max),
  CONSTRAINT chk_myair_daily_coverage
    CHECK (hours_n BETWEEN 1 AND 24
       AND five_min_n BETWEEN hours_n AND 288
       AND minute_n BETWEEN five_min_n AND 1440
       AND complete_hours_n BETWEEN 0 AND hours_n),
  CONSTRAINT chk_myair_daily_profiles
    CHECK (JSON_VALID(five_min_profile) AND JSON_LENGTH(five_min_profile) = 24),
  CONSTRAINT chk_myair_daily_provenance
    CHECK (ambiguous_device_hour_n BETWEEN 0 AND hours_n
       AND ambiguous_firmware_hour_n BETWEEN 0 AND hours_n
       AND mixed_device_5min_n BETWEEN 0 AND five_min_n
       AND mixed_firmware_5min_n BETWEEN 0 AND five_min_n
       AND (deviceId IS NULL OR ambiguous_device_hour_n = 0)
       AND (firmware IS NULL OR ambiguous_firmware_hour_n = 0)),
  CONSTRAINT chk_myair_daily_measurement_counts
    CHECK (
      pm1_hours_n BETWEEN 0 AND hours_n
      AND pm1_5min_n BETWEEN pm1_hours_n AND five_min_n
      AND pm1_minute_n BETWEEN pm1_5min_n AND minute_n
      AND pm1_complete_hours_n BETWEEN 0 AND pm1_hours_n
      AND       pm25_hours_n BETWEEN 0 AND hours_n
      AND pm25_5min_n BETWEEN pm25_hours_n AND five_min_n
      AND pm25_minute_n BETWEEN pm25_5min_n AND minute_n
      AND pm25_complete_hours_n BETWEEN 0 AND pm25_hours_n
      AND       pm10_hours_n BETWEEN 0 AND hours_n
      AND pm10_5min_n BETWEEN pm10_hours_n AND five_min_n
      AND pm10_minute_n BETWEEN pm10_5min_n AND minute_n
      AND pm10_complete_hours_n BETWEEN 0 AND pm10_hours_n
      AND       pc03_hours_n BETWEEN 0 AND hours_n
      AND pc03_5min_n BETWEEN pc03_hours_n AND five_min_n
      AND pc03_minute_n BETWEEN pc03_5min_n AND minute_n
      AND pc03_complete_hours_n BETWEEN 0 AND pc03_hours_n
      AND       pc05_hours_n BETWEEN 0 AND hours_n
      AND pc05_5min_n BETWEEN pc05_hours_n AND five_min_n
      AND pc05_minute_n BETWEEN pc05_5min_n AND minute_n
      AND pc05_complete_hours_n BETWEEN 0 AND pc05_hours_n
      AND       pc1_hours_n BETWEEN 0 AND hours_n
      AND pc1_5min_n BETWEEN pc1_hours_n AND five_min_n
      AND pc1_minute_n BETWEEN pc1_5min_n AND minute_n
      AND pc1_complete_hours_n BETWEEN 0 AND pc1_hours_n
      AND       pc25_hours_n BETWEEN 0 AND hours_n
      AND pc25_5min_n BETWEEN pc25_hours_n AND five_min_n
      AND pc25_minute_n BETWEEN pc25_5min_n AND minute_n
      AND pc25_complete_hours_n BETWEEN 0 AND pc25_hours_n
      AND       pc5_hours_n BETWEEN 0 AND hours_n
      AND pc5_5min_n BETWEEN pc5_hours_n AND five_min_n
      AND pc5_minute_n BETWEEN pc5_5min_n AND minute_n
      AND pc5_complete_hours_n BETWEEN 0 AND pc5_hours_n
      AND       pc10_hours_n BETWEEN 0 AND hours_n
      AND pc10_5min_n BETWEEN pc10_hours_n AND five_min_n
      AND pc10_minute_n BETWEEN pc10_5min_n AND minute_n
      AND pc10_complete_hours_n BETWEEN 0 AND pc10_hours_n
      AND       temperature_hours_n BETWEEN 0 AND hours_n
      AND temperature_5min_n BETWEEN temperature_hours_n AND five_min_n
      AND temperature_minute_n BETWEEN temperature_5min_n AND minute_n
      AND temperature_complete_hours_n BETWEEN 0 AND temperature_hours_n
      AND       humidity_hours_n BETWEEN 0 AND hours_n
      AND humidity_5min_n BETWEEN humidity_hours_n AND five_min_n
      AND humidity_minute_n BETWEEN humidity_5min_n AND minute_n
      AND humidity_complete_hours_n BETWEEN 0 AND humidity_hours_n
      AND       pressure_hours_n BETWEEN 0 AND hours_n
      AND pressure_5min_n BETWEEN pressure_hours_n AND five_min_n
      AND pressure_minute_n BETWEEN pressure_5min_n AND minute_n
      AND pressure_complete_hours_n BETWEEN 0 AND pressure_hours_n
      AND       sound_hours_n BETWEEN 0 AND hours_n
      AND sound_5min_n BETWEEN sound_hours_n AND five_min_n
      AND sound_minute_n BETWEEN sound_5min_n AND minute_n
      AND sound_complete_hours_n BETWEEN 0 AND sound_hours_n
      AND       uvb_hours_n BETWEEN 0 AND hours_n
      AND uvb_5min_n BETWEEN uvb_hours_n AND five_min_n
      AND uvb_minute_n BETWEEN uvb_5min_n AND minute_n
      AND uvb_complete_hours_n BETWEEN 0 AND uvb_hours_n
      AND       light_hours_n BETWEEN 0 AND hours_n
      AND light_5min_n BETWEEN light_hours_n AND five_min_n
      AND light_minute_n BETWEEN light_5min_n AND minute_n
      AND light_complete_hours_n BETWEEN 0 AND light_hours_n
    ),
  CONSTRAINT chk_myair_daily_measurement_stats
    CHECK (
      ((pm1_hours_n = 0 AND pm1_mean IS NULL AND pm1_min IS NULL AND pm1_max IS NULL)
       OR (pm1_hours_n > 0 AND pm1_mean IS NOT NULL AND pm1_min IS NOT NULL
         AND pm1_max IS NOT NULL AND pm1_min <= pm1_mean AND pm1_mean <= pm1_max))
      AND       ((pm25_hours_n = 0 AND pm25_mean IS NULL AND pm25_min IS NULL AND pm25_max IS NULL)
       OR (pm25_hours_n > 0 AND pm25_mean IS NOT NULL AND pm25_min IS NOT NULL
         AND pm25_max IS NOT NULL AND pm25_min <= pm25_mean AND pm25_mean <= pm25_max))
      AND       ((pm10_hours_n = 0 AND pm10_mean IS NULL AND pm10_min IS NULL AND pm10_max IS NULL)
       OR (pm10_hours_n > 0 AND pm10_mean IS NOT NULL AND pm10_min IS NOT NULL
         AND pm10_max IS NOT NULL AND pm10_min <= pm10_mean AND pm10_mean <= pm10_max))
      AND       ((pc03_hours_n = 0 AND pc03_mean IS NULL AND pc03_min IS NULL AND pc03_max IS NULL)
       OR (pc03_hours_n > 0 AND pc03_mean IS NOT NULL AND pc03_min IS NOT NULL
         AND pc03_max IS NOT NULL AND pc03_min <= pc03_mean AND pc03_mean <= pc03_max))
      AND       ((pc05_hours_n = 0 AND pc05_mean IS NULL AND pc05_min IS NULL AND pc05_max IS NULL)
       OR (pc05_hours_n > 0 AND pc05_mean IS NOT NULL AND pc05_min IS NOT NULL
         AND pc05_max IS NOT NULL AND pc05_min <= pc05_mean AND pc05_mean <= pc05_max))
      AND       ((pc1_hours_n = 0 AND pc1_mean IS NULL AND pc1_min IS NULL AND pc1_max IS NULL)
       OR (pc1_hours_n > 0 AND pc1_mean IS NOT NULL AND pc1_min IS NOT NULL
         AND pc1_max IS NOT NULL AND pc1_min <= pc1_mean AND pc1_mean <= pc1_max))
      AND       ((pc25_hours_n = 0 AND pc25_mean IS NULL AND pc25_min IS NULL AND pc25_max IS NULL)
       OR (pc25_hours_n > 0 AND pc25_mean IS NOT NULL AND pc25_min IS NOT NULL
         AND pc25_max IS NOT NULL AND pc25_min <= pc25_mean AND pc25_mean <= pc25_max))
      AND       ((pc5_hours_n = 0 AND pc5_mean IS NULL AND pc5_min IS NULL AND pc5_max IS NULL)
       OR (pc5_hours_n > 0 AND pc5_mean IS NOT NULL AND pc5_min IS NOT NULL
         AND pc5_max IS NOT NULL AND pc5_min <= pc5_mean AND pc5_mean <= pc5_max))
      AND       ((pc10_hours_n = 0 AND pc10_mean IS NULL AND pc10_min IS NULL AND pc10_max IS NULL)
       OR (pc10_hours_n > 0 AND pc10_mean IS NOT NULL AND pc10_min IS NOT NULL
         AND pc10_max IS NOT NULL AND pc10_min <= pc10_mean AND pc10_mean <= pc10_max))
      AND       ((temperature_hours_n = 0 AND temperature_mean IS NULL AND temperature_min IS NULL AND temperature_max IS NULL)
       OR (temperature_hours_n > 0 AND temperature_mean IS NOT NULL AND temperature_min IS NOT NULL
         AND temperature_max IS NOT NULL AND temperature_min <= temperature_mean AND temperature_mean <= temperature_max))
      AND       ((humidity_hours_n = 0 AND humidity_mean IS NULL AND humidity_min IS NULL AND humidity_max IS NULL)
       OR (humidity_hours_n > 0 AND humidity_mean IS NOT NULL AND humidity_min IS NOT NULL
         AND humidity_max IS NOT NULL AND humidity_min <= humidity_mean AND humidity_mean <= humidity_max))
      AND       ((pressure_hours_n = 0 AND pressure_mean IS NULL AND pressure_min IS NULL AND pressure_max IS NULL)
       OR (pressure_hours_n > 0 AND pressure_mean IS NOT NULL AND pressure_min IS NOT NULL
         AND pressure_max IS NOT NULL AND pressure_min <= pressure_mean AND pressure_mean <= pressure_max))
      AND       ((sound_hours_n = 0 AND sound_mean IS NULL AND sound_min IS NULL AND sound_max IS NULL)
       OR (sound_hours_n > 0 AND sound_mean IS NOT NULL AND sound_min IS NOT NULL
         AND sound_max IS NOT NULL AND sound_min <= sound_mean AND sound_mean <= sound_max))
      AND       ((uvb_hours_n = 0 AND uvb_mean IS NULL AND uvb_min IS NULL AND uvb_max IS NULL)
       OR (uvb_hours_n > 0 AND uvb_mean IS NOT NULL AND uvb_min IS NOT NULL
         AND uvb_max IS NOT NULL AND uvb_min <= uvb_mean AND uvb_mean <= uvb_max))
      AND       ((light_hours_n = 0 AND light_mean IS NULL AND light_min IS NULL AND light_max IS NULL)
       OR (light_hours_n > 0 AND light_mean IS NOT NULL AND light_min IS NOT NULL
         AND light_max IS NOT NULL AND light_min <= light_mean AND light_mean <= light_max))
    ),
  CONSTRAINT chk_myair_daily_measurement_profiles
    CHECK (
      JSON_VALID(pm1_5min_profile) AND JSON_LENGTH(pm1_5min_profile) = 24
      AND JSON_VALID(pm25_5min_profile) AND JSON_LENGTH(pm25_5min_profile) = 24
      AND JSON_VALID(pm10_5min_profile) AND JSON_LENGTH(pm10_5min_profile) = 24
      AND JSON_VALID(pc03_5min_profile) AND JSON_LENGTH(pc03_5min_profile) = 24
      AND JSON_VALID(pc05_5min_profile) AND JSON_LENGTH(pc05_5min_profile) = 24
      AND JSON_VALID(pc1_5min_profile) AND JSON_LENGTH(pc1_5min_profile) = 24
      AND JSON_VALID(pc25_5min_profile) AND JSON_LENGTH(pc25_5min_profile) = 24
      AND JSON_VALID(pc5_5min_profile) AND JSON_LENGTH(pc5_5min_profile) = 24
      AND JSON_VALID(pc10_5min_profile) AND JSON_LENGTH(pc10_5min_profile) = 24
      AND JSON_VALID(temperature_5min_profile) AND JSON_LENGTH(temperature_5min_profile) = 24
      AND JSON_VALID(humidity_5min_profile) AND JSON_LENGTH(humidity_5min_profile) = 24
      AND JSON_VALID(pressure_5min_profile) AND JSON_LENGTH(pressure_5min_profile) = 24
      AND JSON_VALID(sound_5min_profile) AND JSON_LENGTH(sound_5min_profile) = 24
      AND JSON_VALID(uvb_5min_profile) AND JSON_LENGTH(uvb_5min_profile) = 24
      AND JSON_VALID(light_5min_profile) AND JSON_LENGTH(light_5min_profile) = 24
    )
) ENGINE = InnoDB;

DELIMITER //

CREATE OR REPLACE PROCEDURE etl_myair_daily()
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
  SELECT COUNT(*) INTO v_source_rows FROM myair_hourly;
  IF v_source_rows = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'myair_hourly is empty; myair_daily was not rebuilt';
  END IF;

  SELECT COUNT(*) INTO v_source_days
  FROM (
    SELECT userId, DATE(hour_ts) AS date
    FROM myair_hourly
    GROUP BY userId, DATE(hour_ts)
  ) AS source_keys;

  DELETE FROM myair_daily;                     -- Preserve the reviewed schema and indexes.
  SET v_deleted_rows = ROW_COUNT();

  INSERT INTO myair_daily (
    userId, date, source_created_at_max,
    hours_n, five_min_n, minute_n,
    complete_hours_n, five_min_profile,
    ambiguous_device_hour_n, ambiguous_firmware_hour_n,
    mixed_device_5min_n, mixed_firmware_5min_n, deviceId, firmware,
    pm1_mean, pm1_min, pm1_max, pm1_hours_n, pm1_5min_n,
    pm1_minute_n, pm1_complete_hours_n, pm1_5min_profile,
    pm25_mean, pm25_min, pm25_max, pm25_hours_n, pm25_5min_n,
    pm25_minute_n, pm25_complete_hours_n, pm25_5min_profile,
    pm10_mean, pm10_min, pm10_max, pm10_hours_n, pm10_5min_n,
    pm10_minute_n, pm10_complete_hours_n, pm10_5min_profile,
    pc03_mean, pc03_min, pc03_max, pc03_hours_n, pc03_5min_n,
    pc03_minute_n, pc03_complete_hours_n, pc03_5min_profile,
    pc05_mean, pc05_min, pc05_max, pc05_hours_n, pc05_5min_n,
    pc05_minute_n, pc05_complete_hours_n, pc05_5min_profile,
    pc1_mean, pc1_min, pc1_max, pc1_hours_n, pc1_5min_n,
    pc1_minute_n, pc1_complete_hours_n, pc1_5min_profile,
    pc25_mean, pc25_min, pc25_max, pc25_hours_n, pc25_5min_n,
    pc25_minute_n, pc25_complete_hours_n, pc25_5min_profile,
    pc5_mean, pc5_min, pc5_max, pc5_hours_n, pc5_5min_n,
    pc5_minute_n, pc5_complete_hours_n, pc5_5min_profile,
    pc10_mean, pc10_min, pc10_max, pc10_hours_n, pc10_5min_n,
    pc10_minute_n, pc10_complete_hours_n, pc10_5min_profile,
    temperature_mean, temperature_min, temperature_max, temperature_hours_n, temperature_5min_n,
    temperature_minute_n, temperature_complete_hours_n, temperature_5min_profile,
    humidity_mean, humidity_min, humidity_max, humidity_hours_n, humidity_5min_n,
    humidity_minute_n, humidity_complete_hours_n, humidity_5min_profile,
    pressure_mean, pressure_min, pressure_max, pressure_hours_n, pressure_5min_n,
    pressure_minute_n, pressure_complete_hours_n, pressure_5min_profile,
    sound_mean, sound_min, sound_max, sound_hours_n, sound_5min_n,
    sound_minute_n, sound_complete_hours_n, sound_5min_profile,
    uvb_mean, uvb_min, uvb_max, uvb_hours_n, uvb_5min_n,
    uvb_minute_n, uvb_complete_hours_n, uvb_5min_profile,
    light_mean, light_min, light_max, light_hours_n, light_5min_n,
    light_minute_n, light_complete_hours_n, light_5min_profile
  )
  WITH RECURSIVE hour_numbers AS (                 -- Materialize exactly the clock hours 00 through 23.
    SELECT 0 AS hour_n
    UNION ALL
    SELECT hour_n + 1 FROM hour_numbers WHERE hour_n < 23
  ),
  daily_keys AS (
    SELECT userId, DATE(hour_ts) AS date
    FROM myair_hourly
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
      h.pm1_mean,
      h.pm1_min,
      h.pm1_max,
      h.pm1_5min_n,
      h.pm1_minute_n,
      h.pm25_mean,
      h.pm25_min,
      h.pm25_max,
      h.pm25_5min_n,
      h.pm25_minute_n,
      h.pm10_mean,
      h.pm10_min,
      h.pm10_max,
      h.pm10_5min_n,
      h.pm10_minute_n,
      h.pc03_mean,
      h.pc03_min,
      h.pc03_max,
      h.pc03_5min_n,
      h.pc03_minute_n,
      h.pc05_mean,
      h.pc05_min,
      h.pc05_max,
      h.pc05_5min_n,
      h.pc05_minute_n,
      h.pc1_mean,
      h.pc1_min,
      h.pc1_max,
      h.pc1_5min_n,
      h.pc1_minute_n,
      h.pc25_mean,
      h.pc25_min,
      h.pc25_max,
      h.pc25_5min_n,
      h.pc25_minute_n,
      h.pc5_mean,
      h.pc5_min,
      h.pc5_max,
      h.pc5_5min_n,
      h.pc5_minute_n,
      h.pc10_mean,
      h.pc10_min,
      h.pc10_max,
      h.pc10_5min_n,
      h.pc10_minute_n,
      h.temperature_mean,
      h.temperature_min,
      h.temperature_max,
      h.temperature_5min_n,
      h.temperature_minute_n,
      h.humidity_mean,
      h.humidity_min,
      h.humidity_max,
      h.humidity_5min_n,
      h.humidity_minute_n,
      h.pressure_mean,
      h.pressure_min,
      h.pressure_max,
      h.pressure_5min_n,
      h.pressure_minute_n,
      h.sound_mean,
      h.sound_min,
      h.sound_max,
      h.sound_5min_n,
      h.sound_minute_n,
      h.uvb_mean,
      h.uvb_min,
      h.uvb_max,
      h.uvb_5min_n,
      h.uvb_minute_n,
      h.light_mean,
      h.light_min,
      h.light_max,
      h.light_5min_n,
      h.light_minute_n
    FROM daily_keys AS k
    CROSS JOIN hour_numbers AS n
    LEFT JOIN myair_hourly AS h
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
    AVG(g.pm1_mean), MIN(g.pm1_min), MAX(g.pm1_max),
    COUNT(g.pm1_mean), COALESCE(SUM(g.pm1_5min_n), 0),
    COALESCE(SUM(g.pm1_minute_n), 0),
    COALESCE(SUM(g.pm1_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.pm1_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.pm25_mean), MIN(g.pm25_min), MAX(g.pm25_max),
    COUNT(g.pm25_mean), COALESCE(SUM(g.pm25_5min_n), 0),
    COALESCE(SUM(g.pm25_minute_n), 0),
    COALESCE(SUM(g.pm25_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.pm25_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.pm10_mean), MIN(g.pm10_min), MAX(g.pm10_max),
    COUNT(g.pm10_mean), COALESCE(SUM(g.pm10_5min_n), 0),
    COALESCE(SUM(g.pm10_minute_n), 0),
    COALESCE(SUM(g.pm10_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.pm10_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.pc03_mean), MIN(g.pc03_min), MAX(g.pc03_max),
    COUNT(g.pc03_mean), COALESCE(SUM(g.pc03_5min_n), 0),
    COALESCE(SUM(g.pc03_minute_n), 0),
    COALESCE(SUM(g.pc03_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.pc03_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.pc05_mean), MIN(g.pc05_min), MAX(g.pc05_max),
    COUNT(g.pc05_mean), COALESCE(SUM(g.pc05_5min_n), 0),
    COALESCE(SUM(g.pc05_minute_n), 0),
    COALESCE(SUM(g.pc05_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.pc05_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.pc1_mean), MIN(g.pc1_min), MAX(g.pc1_max),
    COUNT(g.pc1_mean), COALESCE(SUM(g.pc1_5min_n), 0),
    COALESCE(SUM(g.pc1_minute_n), 0),
    COALESCE(SUM(g.pc1_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.pc1_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.pc25_mean), MIN(g.pc25_min), MAX(g.pc25_max),
    COUNT(g.pc25_mean), COALESCE(SUM(g.pc25_5min_n), 0),
    COALESCE(SUM(g.pc25_minute_n), 0),
    COALESCE(SUM(g.pc25_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.pc25_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.pc5_mean), MIN(g.pc5_min), MAX(g.pc5_max),
    COUNT(g.pc5_mean), COALESCE(SUM(g.pc5_5min_n), 0),
    COALESCE(SUM(g.pc5_minute_n), 0),
    COALESCE(SUM(g.pc5_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.pc5_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.pc10_mean), MIN(g.pc10_min), MAX(g.pc10_max),
    COUNT(g.pc10_mean), COALESCE(SUM(g.pc10_5min_n), 0),
    COALESCE(SUM(g.pc10_minute_n), 0),
    COALESCE(SUM(g.pc10_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.pc10_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.temperature_mean), MIN(g.temperature_min), MAX(g.temperature_max),
    COUNT(g.temperature_mean), COALESCE(SUM(g.temperature_5min_n), 0),
    COALESCE(SUM(g.temperature_minute_n), 0),
    COALESCE(SUM(g.temperature_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.temperature_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.humidity_mean), MIN(g.humidity_min), MAX(g.humidity_max),
    COUNT(g.humidity_mean), COALESCE(SUM(g.humidity_5min_n), 0),
    COALESCE(SUM(g.humidity_minute_n), 0),
    COALESCE(SUM(g.humidity_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.humidity_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.pressure_mean), MIN(g.pressure_min), MAX(g.pressure_max),
    COUNT(g.pressure_mean), COALESCE(SUM(g.pressure_5min_n), 0),
    COALESCE(SUM(g.pressure_minute_n), 0),
    COALESCE(SUM(g.pressure_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.pressure_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.sound_mean), MIN(g.sound_min), MAX(g.sound_max),
    COUNT(g.sound_mean), COALESCE(SUM(g.sound_5min_n), 0),
    COALESCE(SUM(g.sound_minute_n), 0),
    COALESCE(SUM(g.sound_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.sound_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.uvb_mean), MIN(g.uvb_min), MAX(g.uvb_max),
    COUNT(g.uvb_mean), COALESCE(SUM(g.uvb_5min_n), 0),
    COALESCE(SUM(g.uvb_minute_n), 0),
    COALESCE(SUM(g.uvb_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.uvb_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.light_mean), MIN(g.light_min), MAX(g.light_max),
    COUNT(g.light_mean), COALESCE(SUM(g.light_5min_n), 0),
    COALESCE(SUM(g.light_minute_n), 0),
    COALESCE(SUM(g.light_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.light_5min_n, 0) ORDER BY g.hour_n)
  FROM hour_grid AS g
  GROUP BY g.userId, g.date;

  SET v_inserted_rows = ROW_COUNT();
  IF v_inserted_rows <> v_source_days THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'myair_daily output count differs from source day count';
  END IF;
  SELECT COUNT(*) INTO v_total_rows FROM myair_daily;
  IF v_total_rows <> v_source_days THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'myair_daily final count differs from source day count';
  END IF;

  COMMIT;                                          -- Publish only the complete replacement.
  SET v_finished_at = UTC_TIMESTAMP(6);
  SELECT 'full' AS run_mode, v_started_at AS started_at, v_finished_at AS finished_at,
    v_source_rows AS source_hourly_rows, v_source_days AS source_days,
    v_deleted_rows AS deleted_daily_rows, v_inserted_rows AS inserted_daily_rows,
    v_total_rows AS total_daily_rows;
END//

DELIMITER ;
