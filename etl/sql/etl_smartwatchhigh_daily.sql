-- =========================================================
-- etl_smartwatchhigh_daily.sql
--
-- Materialized daily aggregation of smartwatchhigh_hourly.
--
-- One row per device, firmware and calendar date.
-- Continuous daily means are unweighted means of available
-- hourly means.
--
-- Each measurement has a fixed JSON profile of 24 values,
-- ordered from hour 00 to hour 23. Each value reports the
-- number of valid five-minute buckets represented in that
-- hour, from 0 to 12.
--
-- sleeprate is categorical: class counts are summed and no
-- arithmetic mean is calculated.
--
-- No coverage threshold is enforced in the ETL.
-- =========================================================


CREATE TABLE IF NOT EXISTS smartwatchhigh_daily (

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

  heartrate_mean                    DOUBLE NULL,
  heartrate_min                     DOUBLE NULL,
  heartrate_max                     DOUBLE NULL,
  heartrate_raw_n                   INT UNSIGNED NOT NULL,
  heartrate_hours_n                 TINYINT UNSIGNED NOT NULL,
  heartrate_5min_n                  SMALLINT UNSIGNED NOT NULL,
  heartrate_5min_per_hour_mean      DOUBLE NULL,
  heartrate_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  heartrate_5min_profile            JSON NOT NULL,

  oxygens_mean                    DOUBLE NULL,
  oxygens_min                     DOUBLE NULL,
  oxygens_max                     DOUBLE NULL,
  oxygens_raw_n                   INT UNSIGNED NOT NULL,
  oxygens_hours_n                 TINYINT UNSIGNED NOT NULL,
  oxygens_5min_n                  SMALLINT UNSIGNED NOT NULL,
  oxygens_5min_per_hour_mean      DOUBLE NULL,
  oxygens_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  oxygens_5min_profile            JSON NOT NULL,

  breathrate_mean                    DOUBLE NULL,
  breathrate_min                     DOUBLE NULL,
  breathrate_max                     DOUBLE NULL,
  breathrate_raw_n                   INT UNSIGNED NOT NULL,
  breathrate_hours_n                 TINYINT UNSIGNED NOT NULL,
  breathrate_5min_n                  SMALLINT UNSIGNED NOT NULL,
  breathrate_5min_per_hour_mean      DOUBLE NULL,
  breathrate_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  breathrate_5min_profile            JSON NOT NULL,

  sleeprate_raw_n                   INT UNSIGNED NOT NULL,
  sleeprate_hours_n                 TINYINT UNSIGNED NOT NULL,
  sleeprate_5min_n                  SMALLINT UNSIGNED NOT NULL,
  sleeprate_5min_per_hour_mean      DOUBLE NULL,
  sleeprate_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  sleeprate_5min_profile            JSON NOT NULL,
  sleeprate_1_n                     INT UNSIGNED NOT NULL,
  sleeprate_2_n                     INT UNSIGNED NOT NULL,
  sleeprate_3_n                     INT UNSIGNED NOT NULL,
  sleeprate_4_n                     INT UNSIGNED NOT NULL,

  PRIMARY KEY (
    deviceId,
    firmware,
    date
  ),

  INDEX idx_smartwatchhigh_daily_user_date (
    userId,
    date
  ),

  INDEX idx_smartwatchhigh_daily_date (
    date
  )

) ENGINE=InnoDB;


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_smartwatchhigh_daily()
BEGIN

  DROP TABLE IF EXISTS smartwatchhigh_daily;

  CREATE TABLE smartwatchhigh_daily (

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

    heartrate_mean                    DOUBLE NULL,
    heartrate_min                     DOUBLE NULL,
    heartrate_max                     DOUBLE NULL,
    heartrate_raw_n                   INT UNSIGNED NOT NULL,
    heartrate_hours_n                 TINYINT UNSIGNED NOT NULL,
    heartrate_5min_n                  SMALLINT UNSIGNED NOT NULL,
    heartrate_5min_per_hour_mean      DOUBLE NULL,
    heartrate_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    heartrate_5min_profile            JSON NOT NULL,

    oxygens_mean                    DOUBLE NULL,
    oxygens_min                     DOUBLE NULL,
    oxygens_max                     DOUBLE NULL,
    oxygens_raw_n                   INT UNSIGNED NOT NULL,
    oxygens_hours_n                 TINYINT UNSIGNED NOT NULL,
    oxygens_5min_n                  SMALLINT UNSIGNED NOT NULL,
    oxygens_5min_per_hour_mean      DOUBLE NULL,
    oxygens_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    oxygens_5min_profile            JSON NOT NULL,

    breathrate_mean                    DOUBLE NULL,
    breathrate_min                     DOUBLE NULL,
    breathrate_max                     DOUBLE NULL,
    breathrate_raw_n                   INT UNSIGNED NOT NULL,
    breathrate_hours_n                 TINYINT UNSIGNED NOT NULL,
    breathrate_5min_n                  SMALLINT UNSIGNED NOT NULL,
    breathrate_5min_per_hour_mean      DOUBLE NULL,
    breathrate_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    breathrate_5min_profile            JSON NOT NULL,

    sleeprate_raw_n                   INT UNSIGNED NOT NULL,
    sleeprate_hours_n                 TINYINT UNSIGNED NOT NULL,
    sleeprate_5min_n                  SMALLINT UNSIGNED NOT NULL,
    sleeprate_5min_per_hour_mean      DOUBLE NULL,
    sleeprate_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    sleeprate_5min_profile            JSON NOT NULL,
    sleeprate_1_n                     INT UNSIGNED NOT NULL,
    sleeprate_2_n                     INT UNSIGNED NOT NULL,
    sleeprate_3_n                     INT UNSIGNED NOT NULL,
    sleeprate_4_n                     INT UNSIGNED NOT NULL,

    PRIMARY KEY (
      deviceId,
      firmware,
      date
    ),

    INDEX idx_smartwatchhigh_daily_user_date (
      userId,
      date
    ),

    INDEX idx_smartwatchhigh_daily_date (
      date
    )

  ) ENGINE=InnoDB;


  INSERT INTO smartwatchhigh_daily (
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

    heartrate_mean,
    heartrate_min,
    heartrate_max,
    heartrate_raw_n,
    heartrate_hours_n,
    heartrate_5min_n,
    heartrate_5min_per_hour_mean,
    heartrate_complete_hours_n,
    heartrate_5min_profile,

    oxygens_mean,
    oxygens_min,
    oxygens_max,
    oxygens_raw_n,
    oxygens_hours_n,
    oxygens_5min_n,
    oxygens_5min_per_hour_mean,
    oxygens_complete_hours_n,
    oxygens_5min_profile,

    breathrate_mean,
    breathrate_min,
    breathrate_max,
    breathrate_raw_n,
    breathrate_hours_n,
    breathrate_5min_n,
    breathrate_5min_per_hour_mean,
    breathrate_complete_hours_n,
    breathrate_5min_profile,

    sleeprate_raw_n,
    sleeprate_hours_n,
    sleeprate_5min_n,
    sleeprate_5min_per_hour_mean,
    sleeprate_complete_hours_n,
    sleeprate_5min_profile,
    sleeprate_1_n,
    sleeprate_2_n,
    sleeprate_3_n,
    sleeprate_4_n
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

    AVG(heartrate_mean) AS heartrate_mean,
    MIN(heartrate_min) AS heartrate_min,
    MAX(heartrate_max) AS heartrate_max,
    SUM(heartrate_raw_n) AS heartrate_raw_n,
    COUNT(heartrate_mean) AS heartrate_hours_n,
    SUM(heartrate_5min_n) AS heartrate_5min_n,
    AVG(CASE WHEN heartrate_mean IS NOT NULL THEN heartrate_5min_n ELSE NULL END) AS heartrate_5min_per_hour_mean,
    SUM(CASE WHEN heartrate_mean IS NOT NULL AND heartrate_5min_n = 12 THEN 1 ELSE 0 END) AS heartrate_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND heartrate_mean IS NOT NULL
      THEN heartrate_5min_n
      ELSE NULL
    END), 0)
  ) AS heartrate_5min_profile,

    AVG(oxygens_mean) AS oxygens_mean,
    MIN(oxygens_min) AS oxygens_min,
    MAX(oxygens_max) AS oxygens_max,
    SUM(oxygens_raw_n) AS oxygens_raw_n,
    COUNT(oxygens_mean) AS oxygens_hours_n,
    SUM(oxygens_5min_n) AS oxygens_5min_n,
    AVG(CASE WHEN oxygens_mean IS NOT NULL THEN oxygens_5min_n ELSE NULL END) AS oxygens_5min_per_hour_mean,
    SUM(CASE WHEN oxygens_mean IS NOT NULL AND oxygens_5min_n = 12 THEN 1 ELSE 0 END) AS oxygens_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND oxygens_mean IS NOT NULL
      THEN oxygens_5min_n
      ELSE NULL
    END), 0)
  ) AS oxygens_5min_profile,

    AVG(breathrate_mean) AS breathrate_mean,
    MIN(breathrate_min) AS breathrate_min,
    MAX(breathrate_max) AS breathrate_max,
    SUM(breathrate_raw_n) AS breathrate_raw_n,
    COUNT(breathrate_mean) AS breathrate_hours_n,
    SUM(breathrate_5min_n) AS breathrate_5min_n,
    AVG(CASE WHEN breathrate_mean IS NOT NULL THEN breathrate_5min_n ELSE NULL END) AS breathrate_5min_per_hour_mean,
    SUM(CASE WHEN breathrate_mean IS NOT NULL AND breathrate_5min_n = 12 THEN 1 ELSE 0 END) AS breathrate_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND breathrate_mean IS NOT NULL
      THEN breathrate_5min_n
      ELSE NULL
    END), 0)
  ) AS breathrate_5min_profile,

    SUM(sleeprate_raw_n) AS sleeprate_raw_n,
    SUM(CASE WHEN sleeprate_5min_n > 0 THEN 1 ELSE 0 END) AS sleeprate_hours_n,
    SUM(sleeprate_5min_n) AS sleeprate_5min_n,
    AVG(CASE WHEN sleeprate_5min_n > 0 THEN sleeprate_5min_n ELSE NULL END) AS sleeprate_5min_per_hour_mean,
    SUM(CASE WHEN sleeprate_5min_n = 12 THEN 1 ELSE 0 END) AS sleeprate_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND sleeprate_5min_n > 0
      THEN sleeprate_5min_n
      ELSE NULL
    END), 0)
  ) AS sleeprate_5min_profile,
    SUM(sleeprate_1_n) AS sleeprate_1_n,
    SUM(sleeprate_2_n) AS sleeprate_2_n,
    SUM(sleeprate_3_n) AS sleeprate_3_n,
    SUM(sleeprate_4_n) AS sleeprate_4_n

  FROM smartwatchhigh_hourly

  GROUP BY
    userId,
    deviceId,
    firmware,
    DATE(bucket_hour);

END//


DELIMITER ;
