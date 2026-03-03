-- =========================================================
-- smartwatchhigh_hourly full rebuild (IN-PLACE)
-- - strict second-level de-duplication (drop ambiguous seconds)
-- - keep only deviceIds mapping to exactly one userId
-- - rebuild in place: TRUNCATE + INSERT (no swap tables)
-- =========================================================

CREATE TABLE IF NOT EXISTS smartwatchhigh_hourly (
  userId   BIGINT       NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  firmware VARCHAR(128) NOT NULL,
  date     DATE         NOT NULL,
  hour     TINYINT      NOT NULL,

  /* Heart rate */
  heartrate_mean    DOUBLE NULL,
  heartrate_min     DOUBLE NULL,
  heartrate_max     DOUBLE NULL,
  heartrate_valid_n INT    NOT NULL,

  /* Oxygen saturation */
  oxygens_mean      DOUBLE NULL,
  oxygens_min       DOUBLE NULL,
  oxygens_max       DOUBLE NULL,
  oxygens_valid_n   INT    NOT NULL,

  /* Breath rate */
  breathrate_mean      DOUBLE NULL,
  breathrate_min       DOUBLE NULL,
  breathrate_max       DOUBLE NULL,
  breathrate_valid_n   INT    NOT NULL,

  /* Sleep rate */
  sleeprate_mean    DOUBLE NULL,
  sleeprate_min     DOUBLE NULL,
  sleeprate_max     DOUBLE NULL,
  sleeprate_valid_n INT    NOT NULL,

  /* Total rows contributing */
  smartwatchhigh_records_n INT NOT NULL,

  PRIMARY KEY (userId, deviceId, firmware, date, hour),
  INDEX idx_smartwatchhigh_hourly_date_hour (date, hour),
  INDEX idx_smartwatchhigh_hourly_device (deviceId),
  INDEX idx_smartwatchhigh_hourly_user (userId)
) ENGINE=InnoDB;

DELIMITER //

CREATE OR REPLACE PROCEDURE rebuild_smartwatchhigh_hourly()
BEGIN
  /*
    NOTE:
    This rebuild is "in place". During the rebuild window the hourly table
    will be empty (after TRUNCATE) and then progressively refilled.
  */

  TRUNCATE TABLE smartwatchhigh_hourly;

  INSERT INTO smartwatchhigh_hourly (
    userId, deviceId, firmware, date, hour,

    heartrate_mean, heartrate_min, heartrate_max, heartrate_valid_n,
    oxygens_mean,   oxygens_min,   oxygens_max,   oxygens_valid_n,
    breathrate_mean, breathrate_min, breathrate_max, breathrate_valid_n,
    sleeprate_mean, sleeprate_min, sleeprate_max, sleeprate_valid_n,

    smartwatchhigh_records_n
  )
  WITH
  second_bucket_min_created_at AS (
    SELECT deviceId, firmware, event_ts, MIN(created_at) AS min_created_at
    FROM smartwatchhigh
    GROUP BY deviceId, firmware, event_ts
  ),
  second_bucket_created_at_counts AS (
    SELECT deviceId, firmware, event_ts, created_at, COUNT(*) AS cnt_at_created
    FROM smartwatchhigh
    GROUP BY deviceId, firmware, event_ts, created_at
  ),
  second_bucket_unique_minimum AS (
    SELECT m.deviceId, m.firmware, m.event_ts, m.min_created_at
    FROM second_bucket_min_created_at AS m
    JOIN second_bucket_created_at_counts AS c
      ON  c.deviceId = m.deviceId
      AND c.firmware = m.firmware
      AND c.event_ts = m.event_ts
      AND c.created_at = m.min_created_at
    WHERE c.cnt_at_created = 1
  ),
  smartwatchhigh_strict_second_dedup AS (
    SELECT y.*
    FROM smartwatchhigh AS y
    JOIN second_bucket_unique_minimum AS u
      ON  y.deviceId = u.deviceId
      AND y.firmware = u.firmware
      AND y.event_ts = u.event_ts
      AND y.created_at = u.min_created_at
  ),
  user_smartwatchhigh_unique_device AS (
    SELECT deviceId, MIN(userId) AS userId
    FROM user_smartwatchhigh
    GROUP BY deviceId
    HAVING COUNT(DISTINCT userId) = 1
  ),
  smartwatchhigh_strict_second_dedup_with_user AS (
    SELECT d.*, u.userId
    FROM smartwatchhigh_strict_second_dedup AS d
    JOIN user_smartwatchhigh_unique_device AS u
      ON u.deviceId = d.deviceId
  )
  SELECT
    d.userId,
    d.deviceId,
    d.firmware,
    DATE(d.event_ts) AS date,
    HOUR(d.event_ts) AS hour,

    /* Heart rate (>0 valid) */
    CAST(AVG(CASE WHEN d.heartrate > 0 THEN d.heartrate END) AS DOUBLE) AS heartrate_mean,
    CAST(MIN(CASE WHEN d.heartrate > 0 THEN d.heartrate END) AS DOUBLE) AS heartrate_min,
    CAST(MAX(CASE WHEN d.heartrate > 0 THEN d.heartrate END) AS DOUBLE) AS heartrate_max,
    SUM(CASE WHEN d.heartrate > 0 THEN 1 ELSE 0 END) AS heartrate_valid_n,

    /* Oxygen saturation (1..100 valid) */
    CAST(AVG(CASE WHEN d.oxygens BETWEEN 1 AND 100 THEN d.oxygens END) AS DOUBLE) AS oxygens_mean,
    CAST(MIN(CASE WHEN d.oxygens BETWEEN 1 AND 100 THEN d.oxygens END) AS DOUBLE) AS oxygens_min,
    CAST(MAX(CASE WHEN d.oxygens BETWEEN 1 AND 100 THEN d.oxygens END) AS DOUBLE) AS oxygens_max,
    SUM(CASE WHEN d.oxygens BETWEEN 1 AND 100 THEN 1 ELSE 0 END) AS oxygens_valid_n,

    /* Breath rate (1..100 valid) */
    CAST(AVG(CASE WHEN d.breathrate BETWEEN 1 AND 100 THEN d.breathrate END) AS DOUBLE) AS breathrate_mean,
    CAST(MIN(CASE WHEN d.breathrate BETWEEN 1 AND 100 THEN d.breathrate END) AS DOUBLE) AS breathrate_min,
    CAST(MAX(CASE WHEN d.breathrate BETWEEN 1 AND 100 THEN d.breathrate END) AS DOUBLE) AS breathrate_max,
    SUM(CASE WHEN d.breathrate BETWEEN 1 AND 100 THEN 1 ELSE 0 END) AS breathrate_valid_n,

    /* Sleep rate (>0 valid) */
    CAST(AVG(CASE WHEN d.sleeprate > 0 THEN d.sleeprate END) AS DOUBLE) AS sleeprate_mean,
    CAST(MIN(CASE WHEN d.sleeprate > 0 THEN d.sleeprate END) AS DOUBLE) AS sleeprate_min,
    CAST(MAX(CASE WHEN d.sleeprate > 0 THEN d.sleeprate END) AS DOUBLE) AS sleeprate_max,
    SUM(CASE WHEN d.sleeprate > 0 THEN 1 ELSE 0 END) AS sleeprate_valid_n,

    /* Total rows after strict dedup + user binding */
    COUNT(*) AS smartwatchhigh_records_n

  FROM smartwatchhigh_strict_second_dedup_with_user AS d
  GROUP BY d.userId, d.deviceId, d.firmware, DATE(d.event_ts), HOUR(d.event_ts);

END//

DELIMITER ;

