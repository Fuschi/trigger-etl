-- ============================================================================
-- gps_daily.sql
-- Source (read only): gps_hourly. Grain: participant x UTC calendar date.
-- Each daily mean gives equal weight to every available hourly mean.
-- Every JSON coverage profile has 24 entries ordered from hour 00 through 23.
-- ============================================================================

CREATE TABLE IF NOT EXISTS gps_daily (
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

  position_hours_n TINYINT UNSIGNED NOT NULL,
  position_5min_n SMALLINT UNSIGNED NOT NULL,
  position_minute_n SMALLINT UNSIGNED NOT NULL,
  position_complete_hours_n TINYINT UNSIGNED NOT NULL,
  position_5min_profile JSON NOT NULL,
  longitude_mean DOUBLE NOT NULL, longitude_min DOUBLE NOT NULL, longitude_max DOUBLE NOT NULL,
  latitude_mean DOUBLE NOT NULL, latitude_min DOUBLE NOT NULL, latitude_max DOUBLE NOT NULL,

  accuracy_mean DOUBLE NULL, accuracy_min DOUBLE NULL, accuracy_max DOUBLE NULL,
  accuracy_hours_n TINYINT UNSIGNED NOT NULL,
  accuracy_5min_n SMALLINT UNSIGNED NOT NULL,
  accuracy_minute_n SMALLINT UNSIGNED NOT NULL,
  accuracy_complete_hours_n TINYINT UNSIGNED NOT NULL,
  accuracy_5min_profile JSON NOT NULL,

  PRIMARY KEY (userId, date),
  INDEX idx_gps_daily_date (date),
  INDEX idx_gps_daily_source_created (source_created_at_max),
  CONSTRAINT chk_gps_daily_coverage
    CHECK (hours_n BETWEEN 1 AND 24
       AND five_min_n BETWEEN hours_n AND 288
       AND minute_n BETWEEN five_min_n AND 1440
       AND complete_hours_n BETWEEN 0 AND hours_n),
  CONSTRAINT chk_gps_daily_profiles
    CHECK (JSON_VALID(five_min_profile) AND JSON_LENGTH(five_min_profile) = 24),
  CONSTRAINT chk_gps_daily_provenance
    CHECK (ambiguous_device_hour_n BETWEEN 0 AND hours_n
       AND ambiguous_firmware_hour_n BETWEEN 0 AND hours_n
       AND mixed_device_5min_n BETWEEN 0 AND five_min_n
       AND mixed_firmware_5min_n BETWEEN 0 AND five_min_n
       AND (deviceId IS NULL OR ambiguous_device_hour_n = 0)
       AND (firmware IS NULL OR ambiguous_firmware_hour_n = 0)),
  CONSTRAINT chk_gps_daily_position
    CHECK (position_hours_n = hours_n
       AND position_5min_n = five_min_n
       AND position_minute_n = minute_n
       AND position_complete_hours_n = complete_hours_n
       AND JSON_VALID(position_5min_profile) AND JSON_LENGTH(position_5min_profile) = 24),
  CONSTRAINT chk_gps_daily_longitude
    CHECK (longitude_min BETWEEN -180 AND 180 AND longitude_max BETWEEN -180 AND 180
       AND longitude_min <= longitude_mean AND longitude_mean <= longitude_max),
  CONSTRAINT chk_gps_daily_latitude
    CHECK (latitude_min BETWEEN -90 AND 90 AND latitude_max BETWEEN -90 AND 90
       AND latitude_min <= latitude_mean AND latitude_mean <= latitude_max),
  CONSTRAINT chk_gps_daily_measurement_counts
    CHECK (
      accuracy_hours_n BETWEEN 0 AND hours_n
      AND accuracy_5min_n BETWEEN accuracy_hours_n AND five_min_n
      AND accuracy_minute_n BETWEEN accuracy_5min_n AND minute_n
      AND accuracy_complete_hours_n BETWEEN 0 AND accuracy_hours_n
    ),
  CONSTRAINT chk_gps_daily_measurement_stats
    CHECK (
      ((accuracy_hours_n = 0 AND accuracy_mean IS NULL AND accuracy_min IS NULL AND accuracy_max IS NULL)
       OR (accuracy_hours_n > 0 AND accuracy_mean IS NOT NULL AND accuracy_min IS NOT NULL
         AND accuracy_max IS NOT NULL AND accuracy_min <= accuracy_mean AND accuracy_mean <= accuracy_max))
    ),
  CONSTRAINT chk_gps_daily_measurement_profiles
    CHECK (
      JSON_VALID(accuracy_5min_profile) AND JSON_LENGTH(accuracy_5min_profile) = 24
    )
) ENGINE = InnoDB;

DELIMITER //

CREATE OR REPLACE PROCEDURE etl_gps_daily()
SQL SECURITY INVOKER
MODIFIES SQL DATA
main: BEGIN
  DECLARE v_started_at DATETIME(6);
  DECLARE v_finished_at DATETIME(6);
  DECLARE v_source_rows BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_source_days BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_deleted_rows BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_inserted_rows BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_total_rows BIGINT UNSIGNED DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;                                      -- Restore the preceding complete daily table.
    RESIGNAL;
  END;

  SET v_started_at = UTC_TIMESTAMP(6);
  START TRANSACTION WITH CONSISTENT SNAPSHOT;
  SELECT COUNT(*) INTO v_source_rows FROM gps_hourly;
  IF v_source_rows = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'gps_hourly is empty; gps_daily was not rebuilt';
  END IF;
  SELECT COUNT(*) INTO v_source_days
  FROM (SELECT userId, DATE(hour_ts) AS date FROM gps_hourly GROUP BY userId, DATE(hour_ts)) AS source_keys;

  DELETE FROM gps_daily;
  SET v_deleted_rows = ROW_COUNT();
  INSERT INTO gps_daily (
    userId, date, source_created_at_max,
    hours_n, five_min_n, minute_n,
    complete_hours_n, five_min_profile,
    ambiguous_device_hour_n, ambiguous_firmware_hour_n,
    mixed_device_5min_n, mixed_firmware_5min_n, deviceId, firmware,
    position_hours_n, position_5min_n, position_minute_n,
    position_complete_hours_n, position_5min_profile,
    longitude_mean, longitude_min, longitude_max,
    latitude_mean, latitude_min, latitude_max,
    accuracy_mean, accuracy_min, accuracy_max, accuracy_hours_n, accuracy_5min_n,
    accuracy_minute_n, accuracy_complete_hours_n, accuracy_5min_profile
  )
  WITH RECURSIVE hour_numbers AS (
    SELECT 0 AS hour_n UNION ALL SELECT hour_n + 1 FROM hour_numbers WHERE hour_n < 23
  ),
  daily_keys AS (
    SELECT userId, DATE(hour_ts) AS date FROM gps_hourly GROUP BY userId, DATE(hour_ts)
  ),
  hour_grid AS (
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
      h.longitude_mean,
      h.longitude_min,
      h.longitude_max,
      h.latitude_mean,
      h.latitude_min,
      h.latitude_max,
      h.accuracy_mean,
      h.accuracy_min,
      h.accuracy_max,
      h.accuracy_5min_n,
      h.accuracy_minute_n
    FROM daily_keys AS k CROSS JOIN hour_numbers AS n
    LEFT JOIN gps_hourly AS h
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
    COUNT(g.hour_ts), COALESCE(SUM(g.observed_5min_n), 0),
    COALESCE(SUM(g.observed_minute_n), 0), COALESCE(SUM(g.observed_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.observed_5min_n, 0) ORDER BY g.hour_n),
    AVG(g.longitude_mean), MIN(g.longitude_min), MAX(g.longitude_max),
    AVG(g.latitude_mean), MIN(g.latitude_min), MAX(g.latitude_max),
    AVG(g.accuracy_mean), MIN(g.accuracy_min), MAX(g.accuracy_max),
    COUNT(g.accuracy_mean), COALESCE(SUM(g.accuracy_5min_n), 0),
    COALESCE(SUM(g.accuracy_minute_n), 0),
    COALESCE(SUM(g.accuracy_5min_n = 12), 0),
    JSON_ARRAYAGG(COALESCE(g.accuracy_5min_n, 0) ORDER BY g.hour_n)
  FROM hour_grid AS g
  GROUP BY g.userId, g.date;

  SET v_inserted_rows = ROW_COUNT();
  IF v_inserted_rows <> v_source_days THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'gps_daily output count differs from source day count';
  END IF;
  SELECT COUNT(*) INTO v_total_rows FROM gps_daily;
  IF v_total_rows <> v_source_days THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'gps_daily final count differs from source day count';
  END IF;
  COMMIT;
  SET v_finished_at = UTC_TIMESTAMP(6);
  SELECT 'full' AS run_mode, v_started_at AS started_at, v_finished_at AS finished_at,
    v_source_rows AS source_hourly_rows, v_source_days AS source_days,
    v_deleted_rows AS deleted_daily_rows, v_inserted_rows AS inserted_daily_rows,
    v_total_rows AS total_daily_rows;
END//

DELIMITER ;
