-- =========================================================
-- etl_gps_daily.sql
--
-- Materialized daily aggregation of gps_hourly.
--
-- One row per device, firmware and calendar date.
-- Daily means are unweighted means of available hourly means.
--
-- position and accuracy have separate coverage summaries
-- and separate fixed JSON profiles of 24 values.
--
-- Coordinates remain available independently of accuracy.
-- No coverage threshold is enforced in the ETL.
-- =========================================================


CREATE TABLE IF NOT EXISTS gps_daily (

  userId   BIGINT       NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  firmware VARCHAR(128) NOT NULL,

  date DATE NOT NULL,

  records_n                INT UNSIGNED NOT NULL,
  hours_n                  TINYINT UNSIGNED NOT NULL,
  five_min_n               SMALLINT UNSIGNED NOT NULL,
  five_min_per_hour_mean   DOUBLE NULL,
  complete_hours_n         TINYINT UNSIGNED NOT NULL,
  five_min_profile         JSON NOT NULL,

  position_raw_n                   INT UNSIGNED NOT NULL,
  position_hours_n                 TINYINT UNSIGNED NOT NULL,
  position_5min_n                  SMALLINT UNSIGNED NOT NULL,
  position_5min_per_hour_mean      DOUBLE NULL,
  position_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  position_5min_profile            JSON NOT NULL,

  longitude_mean DOUBLE NULL,
  longitude_min  DOUBLE NULL,
  longitude_max  DOUBLE NULL,

  latitude_mean DOUBLE NULL,
  latitude_min  DOUBLE NULL,
  latitude_max  DOUBLE NULL,

  accuracy_mean                    DOUBLE NULL,
  accuracy_min                     DOUBLE NULL,
  accuracy_max                     DOUBLE NULL,
  accuracy_raw_n                   INT UNSIGNED NOT NULL,
  accuracy_hours_n                 TINYINT UNSIGNED NOT NULL,
  accuracy_5min_n                  SMALLINT UNSIGNED NOT NULL,
  accuracy_5min_per_hour_mean      DOUBLE NULL,
  accuracy_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  accuracy_5min_profile            JSON NOT NULL,

  PRIMARY KEY (
    deviceId,
    firmware,
    date
  ),

  INDEX idx_gps_daily_user_date (
    userId,
    date
  ),

  INDEX idx_gps_daily_date (
    date
  )

) ENGINE=InnoDB;


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_gps_daily()
BEGIN

  DROP TABLE IF EXISTS gps_daily;

  CREATE TABLE gps_daily (

    userId   BIGINT       NOT NULL,
    deviceId VARCHAR(128) NOT NULL,
    firmware VARCHAR(128) NOT NULL,

    date DATE NOT NULL,

    records_n                INT UNSIGNED NOT NULL,
    hours_n                  TINYINT UNSIGNED NOT NULL,
    five_min_n               SMALLINT UNSIGNED NOT NULL,
    five_min_per_hour_mean   DOUBLE NULL,
    complete_hours_n         TINYINT UNSIGNED NOT NULL,
    five_min_profile         JSON NOT NULL,

    position_raw_n                   INT UNSIGNED NOT NULL,
    position_hours_n                 TINYINT UNSIGNED NOT NULL,
    position_5min_n                  SMALLINT UNSIGNED NOT NULL,
    position_5min_per_hour_mean      DOUBLE NULL,
    position_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    position_5min_profile            JSON NOT NULL,

    longitude_mean DOUBLE NULL,
    longitude_min  DOUBLE NULL,
    longitude_max  DOUBLE NULL,

    latitude_mean DOUBLE NULL,
    latitude_min  DOUBLE NULL,
    latitude_max  DOUBLE NULL,

    accuracy_mean                    DOUBLE NULL,
    accuracy_min                     DOUBLE NULL,
    accuracy_max                     DOUBLE NULL,
    accuracy_raw_n                   INT UNSIGNED NOT NULL,
    accuracy_hours_n                 TINYINT UNSIGNED NOT NULL,
    accuracy_5min_n                  SMALLINT UNSIGNED NOT NULL,
    accuracy_5min_per_hour_mean      DOUBLE NULL,
    accuracy_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    accuracy_5min_profile            JSON NOT NULL,

    PRIMARY KEY (
      deviceId,
      firmware,
      date
    ),

    INDEX idx_gps_daily_user_date (
      userId,
      date
    ),

    INDEX idx_gps_daily_date (
      date
    )

  ) ENGINE=InnoDB;


  INSERT INTO gps_daily (
    userId,
    deviceId,
    firmware,
    date,

    records_n,
    hours_n,
    five_min_n,
    five_min_per_hour_mean,
    complete_hours_n,
    five_min_profile,

    position_raw_n,
    position_hours_n,
    position_5min_n,
    position_5min_per_hour_mean,
    position_complete_hours_n,
    position_5min_profile,

    longitude_mean,
    longitude_min,
    longitude_max,

    latitude_mean,
    latitude_min,
    latitude_max,

    accuracy_mean,
    accuracy_min,
    accuracy_max,
    accuracy_raw_n,
    accuracy_hours_n,
    accuracy_5min_n,
    accuracy_5min_per_hour_mean,
    accuracy_complete_hours_n,
    accuracy_5min_profile
  )

  SELECT
    userId,
    deviceId,
    firmware,
    DATE(bucket_hour) AS date,

    SUM(records_n) AS records_n,
    COUNT(*) AS hours_n,
    SUM(five_min_n) AS five_min_n,
    AVG(five_min_n) AS five_min_per_hour_mean,
    SUM(CASE WHEN five_min_n = 12 THEN 1 ELSE 0 END) AS complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22
      THEN five_min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23
      THEN five_min_n
      ELSE NULL
    END), 0)
  ) AS five_min_profile,

    SUM(position_raw_n) AS position_raw_n,
    COUNT(longitude_mean) AS position_hours_n,
    SUM(position_5min_n) AS position_5min_n,
    AVG(CASE WHEN longitude_mean IS NOT NULL THEN position_5min_n ELSE NULL END) AS position_5min_per_hour_mean,
    SUM(CASE WHEN longitude_mean IS NOT NULL AND position_5min_n = 12 THEN 1 ELSE 0 END) AS position_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND longitude_mean IS NOT NULL
      THEN position_5min_n
      ELSE NULL
    END), 0)
  ) AS position_5min_profile,

    AVG(longitude_mean) AS longitude_mean,
    MIN(longitude_min) AS longitude_min,
    MAX(longitude_max) AS longitude_max,

    AVG(latitude_mean) AS latitude_mean,
    MIN(latitude_min) AS latitude_min,
    MAX(latitude_max) AS latitude_max,

    AVG(accuracy_mean) AS accuracy_mean,
    MIN(accuracy_min) AS accuracy_min,
    MAX(accuracy_max) AS accuracy_max,
    SUM(accuracy_raw_n) AS accuracy_raw_n,
    COUNT(accuracy_mean) AS accuracy_hours_n,
    SUM(accuracy_5min_n) AS accuracy_5min_n,
    AVG(CASE WHEN accuracy_mean IS NOT NULL THEN accuracy_5min_n ELSE NULL END) AS accuracy_5min_per_hour_mean,
    SUM(CASE WHEN accuracy_mean IS NOT NULL AND accuracy_5min_n = 12 THEN 1 ELSE 0 END) AS accuracy_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND accuracy_mean IS NOT NULL
      THEN accuracy_5min_n
      ELSE NULL
    END), 0)
  ) AS accuracy_5min_profile

  FROM gps_hourly

  GROUP BY
    userId,
    deviceId,
    firmware,
    DATE(bucket_hour);

END//


DELIMITER ;
