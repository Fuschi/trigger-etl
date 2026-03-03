-- =========================================================
-- gps_hourly full rebuild (IN-PLACE)
-- - strict second-level de-duplication (drop ambiguous seconds)
-- - keep only deviceIds mapping to exactly one userId
-- - rebuild in place: TRUNCATE + INSERT (no swap tables)
-- =========================================================

CREATE TABLE IF NOT EXISTS gps_hourly (
  userId   BIGINT       NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  firmware VARCHAR(128) NOT NULL,
  date     DATE         NOT NULL,
  hour     TINYINT      NOT NULL,

  /* Longitude */
  longitude_mean    DOUBLE NULL,
  longitude_min     DOUBLE NULL,
  longitude_max     DOUBLE NULL,
  longitude_valid_n INT    NOT NULL,

  /* Latitude */
  latitude_mean     DOUBLE NULL,
  latitude_min      DOUBLE NULL,
  latitude_max      DOUBLE NULL,
  latitude_valid_n  INT    NOT NULL,

  /* Accuracy */
  accuracy_mean     DOUBLE NULL,
  accuracy_min      DOUBLE NULL,
  accuracy_max      DOUBLE NULL,
  accuracy_valid_n  INT    NOT NULL,

  /* Total rows contributing */
  gps_records_n INT NOT NULL,

  PRIMARY KEY (userId, deviceId, firmware, date, hour),
  INDEX idx_gps_hourly_date_hour (date, hour),
  INDEX idx_gps_hourly_device (deviceId),
  INDEX idx_gps_hourly_user (userId)
) ENGINE=InnoDB;

DELIMITER //

CREATE OR REPLACE PROCEDURE rebuild_gps_hourly()
BEGIN
  /*
    NOTE:
    This rebuild is "in place". During the rebuild window the hourly table
    will be empty (after TRUNCATE) and then progressively refilled.
  */

  TRUNCATE TABLE gps_hourly;

  INSERT INTO gps_hourly (
    userId, deviceId, firmware, date, hour,

    longitude_mean, longitude_min, longitude_max, longitude_valid_n,
    latitude_mean,  latitude_min,  latitude_max,  latitude_valid_n,
    accuracy_mean,  accuracy_min,  accuracy_max,  accuracy_valid_n,

    gps_records_n
  )
  WITH
  second_bucket_min_created_at AS (
    SELECT deviceId, firmware, event_ts, MIN(created_at) AS min_created_at
    FROM gps
    GROUP BY deviceId, firmware, event_ts
  ),
  second_bucket_created_at_counts AS (
    SELECT deviceId, firmware, event_ts, created_at, COUNT(*) AS cnt_at_created
    FROM gps
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
  gps_strict_second_dedup AS (
    SELECT y.*
    FROM gps AS y
    JOIN second_bucket_unique_minimum AS u
      ON  y.deviceId = u.deviceId
      AND y.firmware = u.firmware
      AND y.event_ts = u.event_ts
      AND y.created_at = u.min_created_at
  ),
  user_gps_unique_device AS (
    SELECT deviceId, MIN(userId) AS userId
    FROM user_gps
    GROUP BY deviceId
    HAVING COUNT(DISTINCT userId) = 1
  ),
  gps_strict_second_dedup_with_user AS (
    SELECT d.*, u.userId
    FROM gps_strict_second_dedup AS d
    JOIN user_gps_unique_device AS u
      ON u.deviceId = d.deviceId
  )
  SELECT
    d.userId,
    d.deviceId,
    d.firmware,
    DATE(d.event_ts) AS date,
    HOUR(d.event_ts) AS hour,

    /* Longitude (-180..180 valid) */
    CAST(AVG(CASE WHEN d.longitude BETWEEN -180 AND 180 THEN d.longitude END) AS DOUBLE) AS longitude_mean,
    CAST(MIN(CASE WHEN d.longitude BETWEEN -180 AND 180 THEN d.longitude END) AS DOUBLE) AS longitude_min,
    CAST(MAX(CASE WHEN d.longitude BETWEEN -180 AND 180 THEN d.longitude END) AS DOUBLE) AS longitude_max,
    SUM(CASE WHEN d.longitude BETWEEN -180 AND 180 THEN 1 ELSE 0 END) AS longitude_valid_n,

    /* Latitude (-90..90 valid) */
    CAST(AVG(CASE WHEN d.latitude BETWEEN -90 AND 90 THEN d.latitude END) AS DOUBLE) AS latitude_mean,
    CAST(MIN(CASE WHEN d.latitude BETWEEN -90 AND 90 THEN d.latitude END) AS DOUBLE) AS latitude_min,
    CAST(MAX(CASE WHEN d.latitude BETWEEN -90 AND 90 THEN d.latitude END) AS DOUBLE) AS latitude_max,
    SUM(CASE WHEN d.latitude BETWEEN -90 AND 90 THEN 1 ELSE 0 END) AS latitude_valid_n,

    /* Accuracy (>0 valid) */
    CAST(AVG(CASE WHEN d.accuracy > 0 THEN d.accuracy END) AS DOUBLE) AS accuracy_mean,
    CAST(MIN(CASE WHEN d.accuracy > 0 THEN d.accuracy END) AS DOUBLE) AS accuracy_min,
    CAST(MAX(CASE WHEN d.accuracy > 0 THEN d.accuracy END) AS DOUBLE) AS accuracy_max,
    SUM(CASE WHEN d.accuracy > 0 THEN 1 ELSE 0 END) AS accuracy_valid_n,

    /* Total rows after strict dedup + user binding */
    COUNT(*) AS gps_records_n

  FROM gps_strict_second_dedup_with_user AS d
  GROUP BY d.userId, d.deviceId, d.firmware, DATE(d.event_ts), HOUR(d.event_ts);

END//

DELIMITER ;

