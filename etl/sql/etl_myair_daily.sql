-- =========================================================
-- etl_myair_daily.sql
--
-- Materialized daily aggregation of myair_hourly.
--
-- One row per device, firmware and calendar date.
--
-- Daily means are calculated from hourly means. Each hour
-- with an available measurement contributes one equally
-- weighted value to the daily mean.
--
-- Coverage is retained at two levels:
--   - scalar summaries, useful for filtering and QC
--   - a fixed JSON array of 24 values, ordered from hour
--     00 to hour 23
--
-- Each profile value is the number of valid five-minute
-- buckets represented in that hour:
--   0  = no valid value in the hour
--   1  = 5 minutes represented
--   ...
--   12 = complete hourly coverage
--
-- General coverage fields describe the sensor table as a
-- whole. Metric-specific fields describe only the hours and
-- five-minute buckets that contributed to that measurement.
--
-- No coverage threshold is enforced in the ETL.
-- =========================================================


CREATE TABLE IF NOT EXISTS myair_daily (

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

  pm1_mean                    DOUBLE NULL,
  pm1_min                     DOUBLE NULL,
  pm1_max                     DOUBLE NULL,
  pm1_raw_n                   INT UNSIGNED NOT NULL,
  pm1_hours_n                 TINYINT UNSIGNED NOT NULL,
  pm1_5min_n                  SMALLINT UNSIGNED NOT NULL,
  pm1_5min_per_hour_mean      DOUBLE NULL,
  pm1_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  pm1_5min_profile            JSON NOT NULL,

  pm25_mean                    DOUBLE NULL,
  pm25_min                     DOUBLE NULL,
  pm25_max                     DOUBLE NULL,
  pm25_raw_n                   INT UNSIGNED NOT NULL,
  pm25_hours_n                 TINYINT UNSIGNED NOT NULL,
  pm25_5min_n                  SMALLINT UNSIGNED NOT NULL,
  pm25_5min_per_hour_mean      DOUBLE NULL,
  pm25_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  pm25_5min_profile            JSON NOT NULL,

  pm10_mean                    DOUBLE NULL,
  pm10_min                     DOUBLE NULL,
  pm10_max                     DOUBLE NULL,
  pm10_raw_n                   INT UNSIGNED NOT NULL,
  pm10_hours_n                 TINYINT UNSIGNED NOT NULL,
  pm10_5min_n                  SMALLINT UNSIGNED NOT NULL,
  pm10_5min_per_hour_mean      DOUBLE NULL,
  pm10_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  pm10_5min_profile            JSON NOT NULL,

  pc03_mean                    DOUBLE NULL,
  pc03_min                     DOUBLE NULL,
  pc03_max                     DOUBLE NULL,
  pc03_raw_n                   INT UNSIGNED NOT NULL,
  pc03_hours_n                 TINYINT UNSIGNED NOT NULL,
  pc03_5min_n                  SMALLINT UNSIGNED NOT NULL,
  pc03_5min_per_hour_mean      DOUBLE NULL,
  pc03_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  pc03_5min_profile            JSON NOT NULL,

  pc05_mean                    DOUBLE NULL,
  pc05_min                     DOUBLE NULL,
  pc05_max                     DOUBLE NULL,
  pc05_raw_n                   INT UNSIGNED NOT NULL,
  pc05_hours_n                 TINYINT UNSIGNED NOT NULL,
  pc05_5min_n                  SMALLINT UNSIGNED NOT NULL,
  pc05_5min_per_hour_mean      DOUBLE NULL,
  pc05_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  pc05_5min_profile            JSON NOT NULL,

  pc1_mean                    DOUBLE NULL,
  pc1_min                     DOUBLE NULL,
  pc1_max                     DOUBLE NULL,
  pc1_raw_n                   INT UNSIGNED NOT NULL,
  pc1_hours_n                 TINYINT UNSIGNED NOT NULL,
  pc1_5min_n                  SMALLINT UNSIGNED NOT NULL,
  pc1_5min_per_hour_mean      DOUBLE NULL,
  pc1_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  pc1_5min_profile            JSON NOT NULL,

  pc25_mean                    DOUBLE NULL,
  pc25_min                     DOUBLE NULL,
  pc25_max                     DOUBLE NULL,
  pc25_raw_n                   INT UNSIGNED NOT NULL,
  pc25_hours_n                 TINYINT UNSIGNED NOT NULL,
  pc25_5min_n                  SMALLINT UNSIGNED NOT NULL,
  pc25_5min_per_hour_mean      DOUBLE NULL,
  pc25_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  pc25_5min_profile            JSON NOT NULL,

  pc5_mean                    DOUBLE NULL,
  pc5_min                     DOUBLE NULL,
  pc5_max                     DOUBLE NULL,
  pc5_raw_n                   INT UNSIGNED NOT NULL,
  pc5_hours_n                 TINYINT UNSIGNED NOT NULL,
  pc5_5min_n                  SMALLINT UNSIGNED NOT NULL,
  pc5_5min_per_hour_mean      DOUBLE NULL,
  pc5_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  pc5_5min_profile            JSON NOT NULL,

  pc10_mean                    DOUBLE NULL,
  pc10_min                     DOUBLE NULL,
  pc10_max                     DOUBLE NULL,
  pc10_raw_n                   INT UNSIGNED NOT NULL,
  pc10_hours_n                 TINYINT UNSIGNED NOT NULL,
  pc10_5min_n                  SMALLINT UNSIGNED NOT NULL,
  pc10_5min_per_hour_mean      DOUBLE NULL,
  pc10_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  pc10_5min_profile            JSON NOT NULL,

  temperature_mean                    DOUBLE NULL,
  temperature_min                     DOUBLE NULL,
  temperature_max                     DOUBLE NULL,
  temperature_raw_n                   INT UNSIGNED NOT NULL,
  temperature_hours_n                 TINYINT UNSIGNED NOT NULL,
  temperature_5min_n                  SMALLINT UNSIGNED NOT NULL,
  temperature_5min_per_hour_mean      DOUBLE NULL,
  temperature_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  temperature_5min_profile            JSON NOT NULL,

  humidity_mean                    DOUBLE NULL,
  humidity_min                     DOUBLE NULL,
  humidity_max                     DOUBLE NULL,
  humidity_raw_n                   INT UNSIGNED NOT NULL,
  humidity_hours_n                 TINYINT UNSIGNED NOT NULL,
  humidity_5min_n                  SMALLINT UNSIGNED NOT NULL,
  humidity_5min_per_hour_mean      DOUBLE NULL,
  humidity_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  humidity_5min_profile            JSON NOT NULL,

  pressure_mean                    DOUBLE NULL,
  pressure_min                     DOUBLE NULL,
  pressure_max                     DOUBLE NULL,
  pressure_raw_n                   INT UNSIGNED NOT NULL,
  pressure_hours_n                 TINYINT UNSIGNED NOT NULL,
  pressure_5min_n                  SMALLINT UNSIGNED NOT NULL,
  pressure_5min_per_hour_mean      DOUBLE NULL,
  pressure_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  pressure_5min_profile            JSON NOT NULL,

  sound_mean                    DOUBLE NULL,
  sound_min                     DOUBLE NULL,
  sound_max                     DOUBLE NULL,
  sound_raw_n                   INT UNSIGNED NOT NULL,
  sound_hours_n                 TINYINT UNSIGNED NOT NULL,
  sound_5min_n                  SMALLINT UNSIGNED NOT NULL,
  sound_5min_per_hour_mean      DOUBLE NULL,
  sound_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  sound_5min_profile            JSON NOT NULL,

  uvb_mean                    DOUBLE NULL,
  uvb_min                     DOUBLE NULL,
  uvb_max                     DOUBLE NULL,
  uvb_raw_n                   INT UNSIGNED NOT NULL,
  uvb_hours_n                 TINYINT UNSIGNED NOT NULL,
  uvb_5min_n                  SMALLINT UNSIGNED NOT NULL,
  uvb_5min_per_hour_mean      DOUBLE NULL,
  uvb_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  uvb_5min_profile            JSON NOT NULL,

  light_mean                    DOUBLE NULL,
  light_min                     DOUBLE NULL,
  light_max                     DOUBLE NULL,
  light_raw_n                   INT UNSIGNED NOT NULL,
  light_hours_n                 TINYINT UNSIGNED NOT NULL,
  light_5min_n                  SMALLINT UNSIGNED NOT NULL,
  light_5min_per_hour_mean      DOUBLE NULL,
  light_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  light_5min_profile            JSON NOT NULL,

  PRIMARY KEY (
    deviceId,
    firmware,
    date
  ),

  INDEX idx_myair_daily_user_date (
    userId,
    date
  ),

  INDEX idx_myair_daily_date (
    date
  )

) ENGINE=InnoDB;


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_myair_daily()
BEGIN

  -- Full rebuild of the materialized daily table
  DROP TABLE IF EXISTS myair_daily;

  CREATE TABLE myair_daily (

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

    pm1_mean                    DOUBLE NULL,
    pm1_min                     DOUBLE NULL,
    pm1_max                     DOUBLE NULL,
    pm1_raw_n                   INT UNSIGNED NOT NULL,
    pm1_hours_n                 TINYINT UNSIGNED NOT NULL,
    pm1_5min_n                  SMALLINT UNSIGNED NOT NULL,
    pm1_5min_per_hour_mean      DOUBLE NULL,
    pm1_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    pm1_5min_profile            JSON NOT NULL,

    pm25_mean                    DOUBLE NULL,
    pm25_min                     DOUBLE NULL,
    pm25_max                     DOUBLE NULL,
    pm25_raw_n                   INT UNSIGNED NOT NULL,
    pm25_hours_n                 TINYINT UNSIGNED NOT NULL,
    pm25_5min_n                  SMALLINT UNSIGNED NOT NULL,
    pm25_5min_per_hour_mean      DOUBLE NULL,
    pm25_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    pm25_5min_profile            JSON NOT NULL,

    pm10_mean                    DOUBLE NULL,
    pm10_min                     DOUBLE NULL,
    pm10_max                     DOUBLE NULL,
    pm10_raw_n                   INT UNSIGNED NOT NULL,
    pm10_hours_n                 TINYINT UNSIGNED NOT NULL,
    pm10_5min_n                  SMALLINT UNSIGNED NOT NULL,
    pm10_5min_per_hour_mean      DOUBLE NULL,
    pm10_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    pm10_5min_profile            JSON NOT NULL,

    pc03_mean                    DOUBLE NULL,
    pc03_min                     DOUBLE NULL,
    pc03_max                     DOUBLE NULL,
    pc03_raw_n                   INT UNSIGNED NOT NULL,
    pc03_hours_n                 TINYINT UNSIGNED NOT NULL,
    pc03_5min_n                  SMALLINT UNSIGNED NOT NULL,
    pc03_5min_per_hour_mean      DOUBLE NULL,
    pc03_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    pc03_5min_profile            JSON NOT NULL,

    pc05_mean                    DOUBLE NULL,
    pc05_min                     DOUBLE NULL,
    pc05_max                     DOUBLE NULL,
    pc05_raw_n                   INT UNSIGNED NOT NULL,
    pc05_hours_n                 TINYINT UNSIGNED NOT NULL,
    pc05_5min_n                  SMALLINT UNSIGNED NOT NULL,
    pc05_5min_per_hour_mean      DOUBLE NULL,
    pc05_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    pc05_5min_profile            JSON NOT NULL,

    pc1_mean                    DOUBLE NULL,
    pc1_min                     DOUBLE NULL,
    pc1_max                     DOUBLE NULL,
    pc1_raw_n                   INT UNSIGNED NOT NULL,
    pc1_hours_n                 TINYINT UNSIGNED NOT NULL,
    pc1_5min_n                  SMALLINT UNSIGNED NOT NULL,
    pc1_5min_per_hour_mean      DOUBLE NULL,
    pc1_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    pc1_5min_profile            JSON NOT NULL,

    pc25_mean                    DOUBLE NULL,
    pc25_min                     DOUBLE NULL,
    pc25_max                     DOUBLE NULL,
    pc25_raw_n                   INT UNSIGNED NOT NULL,
    pc25_hours_n                 TINYINT UNSIGNED NOT NULL,
    pc25_5min_n                  SMALLINT UNSIGNED NOT NULL,
    pc25_5min_per_hour_mean      DOUBLE NULL,
    pc25_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    pc25_5min_profile            JSON NOT NULL,

    pc5_mean                    DOUBLE NULL,
    pc5_min                     DOUBLE NULL,
    pc5_max                     DOUBLE NULL,
    pc5_raw_n                   INT UNSIGNED NOT NULL,
    pc5_hours_n                 TINYINT UNSIGNED NOT NULL,
    pc5_5min_n                  SMALLINT UNSIGNED NOT NULL,
    pc5_5min_per_hour_mean      DOUBLE NULL,
    pc5_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    pc5_5min_profile            JSON NOT NULL,

    pc10_mean                    DOUBLE NULL,
    pc10_min                     DOUBLE NULL,
    pc10_max                     DOUBLE NULL,
    pc10_raw_n                   INT UNSIGNED NOT NULL,
    pc10_hours_n                 TINYINT UNSIGNED NOT NULL,
    pc10_5min_n                  SMALLINT UNSIGNED NOT NULL,
    pc10_5min_per_hour_mean      DOUBLE NULL,
    pc10_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    pc10_5min_profile            JSON NOT NULL,

    temperature_mean                    DOUBLE NULL,
    temperature_min                     DOUBLE NULL,
    temperature_max                     DOUBLE NULL,
    temperature_raw_n                   INT UNSIGNED NOT NULL,
    temperature_hours_n                 TINYINT UNSIGNED NOT NULL,
    temperature_5min_n                  SMALLINT UNSIGNED NOT NULL,
    temperature_5min_per_hour_mean      DOUBLE NULL,
    temperature_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    temperature_5min_profile            JSON NOT NULL,

    humidity_mean                    DOUBLE NULL,
    humidity_min                     DOUBLE NULL,
    humidity_max                     DOUBLE NULL,
    humidity_raw_n                   INT UNSIGNED NOT NULL,
    humidity_hours_n                 TINYINT UNSIGNED NOT NULL,
    humidity_5min_n                  SMALLINT UNSIGNED NOT NULL,
    humidity_5min_per_hour_mean      DOUBLE NULL,
    humidity_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    humidity_5min_profile            JSON NOT NULL,

    pressure_mean                    DOUBLE NULL,
    pressure_min                     DOUBLE NULL,
    pressure_max                     DOUBLE NULL,
    pressure_raw_n                   INT UNSIGNED NOT NULL,
    pressure_hours_n                 TINYINT UNSIGNED NOT NULL,
    pressure_5min_n                  SMALLINT UNSIGNED NOT NULL,
    pressure_5min_per_hour_mean      DOUBLE NULL,
    pressure_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    pressure_5min_profile            JSON NOT NULL,

    sound_mean                    DOUBLE NULL,
    sound_min                     DOUBLE NULL,
    sound_max                     DOUBLE NULL,
    sound_raw_n                   INT UNSIGNED NOT NULL,
    sound_hours_n                 TINYINT UNSIGNED NOT NULL,
    sound_5min_n                  SMALLINT UNSIGNED NOT NULL,
    sound_5min_per_hour_mean      DOUBLE NULL,
    sound_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    sound_5min_profile            JSON NOT NULL,

    uvb_mean                    DOUBLE NULL,
    uvb_min                     DOUBLE NULL,
    uvb_max                     DOUBLE NULL,
    uvb_raw_n                   INT UNSIGNED NOT NULL,
    uvb_hours_n                 TINYINT UNSIGNED NOT NULL,
    uvb_5min_n                  SMALLINT UNSIGNED NOT NULL,
    uvb_5min_per_hour_mean      DOUBLE NULL,
    uvb_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    uvb_5min_profile            JSON NOT NULL,

    light_mean                    DOUBLE NULL,
    light_min                     DOUBLE NULL,
    light_max                     DOUBLE NULL,
    light_raw_n                   INT UNSIGNED NOT NULL,
    light_hours_n                 TINYINT UNSIGNED NOT NULL,
    light_5min_n                  SMALLINT UNSIGNED NOT NULL,
    light_5min_per_hour_mean      DOUBLE NULL,
    light_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    light_5min_profile            JSON NOT NULL,

    PRIMARY KEY (
      deviceId,
      firmware,
      date
    ),

    INDEX idx_myair_daily_user_date (
      userId,
      date
    ),

    INDEX idx_myair_daily_date (
      date
    )

  ) ENGINE=InnoDB;


  INSERT INTO myair_daily (
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

    pm1_mean,
    pm1_min,
    pm1_max,
    pm1_raw_n,
    pm1_hours_n,
    pm1_5min_n,
    pm1_5min_per_hour_mean,
    pm1_complete_hours_n,
    pm1_5min_profile,

    pm25_mean,
    pm25_min,
    pm25_max,
    pm25_raw_n,
    pm25_hours_n,
    pm25_5min_n,
    pm25_5min_per_hour_mean,
    pm25_complete_hours_n,
    pm25_5min_profile,

    pm10_mean,
    pm10_min,
    pm10_max,
    pm10_raw_n,
    pm10_hours_n,
    pm10_5min_n,
    pm10_5min_per_hour_mean,
    pm10_complete_hours_n,
    pm10_5min_profile,

    pc03_mean,
    pc03_min,
    pc03_max,
    pc03_raw_n,
    pc03_hours_n,
    pc03_5min_n,
    pc03_5min_per_hour_mean,
    pc03_complete_hours_n,
    pc03_5min_profile,

    pc05_mean,
    pc05_min,
    pc05_max,
    pc05_raw_n,
    pc05_hours_n,
    pc05_5min_n,
    pc05_5min_per_hour_mean,
    pc05_complete_hours_n,
    pc05_5min_profile,

    pc1_mean,
    pc1_min,
    pc1_max,
    pc1_raw_n,
    pc1_hours_n,
    pc1_5min_n,
    pc1_5min_per_hour_mean,
    pc1_complete_hours_n,
    pc1_5min_profile,

    pc25_mean,
    pc25_min,
    pc25_max,
    pc25_raw_n,
    pc25_hours_n,
    pc25_5min_n,
    pc25_5min_per_hour_mean,
    pc25_complete_hours_n,
    pc25_5min_profile,

    pc5_mean,
    pc5_min,
    pc5_max,
    pc5_raw_n,
    pc5_hours_n,
    pc5_5min_n,
    pc5_5min_per_hour_mean,
    pc5_complete_hours_n,
    pc5_5min_profile,

    pc10_mean,
    pc10_min,
    pc10_max,
    pc10_raw_n,
    pc10_hours_n,
    pc10_5min_n,
    pc10_5min_per_hour_mean,
    pc10_complete_hours_n,
    pc10_5min_profile,

    temperature_mean,
    temperature_min,
    temperature_max,
    temperature_raw_n,
    temperature_hours_n,
    temperature_5min_n,
    temperature_5min_per_hour_mean,
    temperature_complete_hours_n,
    temperature_5min_profile,

    humidity_mean,
    humidity_min,
    humidity_max,
    humidity_raw_n,
    humidity_hours_n,
    humidity_5min_n,
    humidity_5min_per_hour_mean,
    humidity_complete_hours_n,
    humidity_5min_profile,

    pressure_mean,
    pressure_min,
    pressure_max,
    pressure_raw_n,
    pressure_hours_n,
    pressure_5min_n,
    pressure_5min_per_hour_mean,
    pressure_complete_hours_n,
    pressure_5min_profile,

    sound_mean,
    sound_min,
    sound_max,
    sound_raw_n,
    sound_hours_n,
    sound_5min_n,
    sound_5min_per_hour_mean,
    sound_complete_hours_n,
    sound_5min_profile,

    uvb_mean,
    uvb_min,
    uvb_max,
    uvb_raw_n,
    uvb_hours_n,
    uvb_5min_n,
    uvb_5min_per_hour_mean,
    uvb_complete_hours_n,
    uvb_5min_profile,

    light_mean,
    light_min,
    light_max,
    light_raw_n,
    light_hours_n,
    light_5min_n,
    light_5min_per_hour_mean,
    light_complete_hours_n,
    light_5min_profile
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

    AVG(pm1_mean) AS pm1_mean,
    MIN(pm1_min) AS pm1_min,
    MAX(pm1_max) AS pm1_max,
    SUM(pm1_raw_n) AS pm1_raw_n,
    COUNT(pm1_mean) AS pm1_hours_n,
    SUM(pm1_5min_n) AS pm1_5min_n,
    AVG(CASE WHEN pm1_mean IS NOT NULL THEN pm1_5min_n ELSE NULL END) AS pm1_5min_per_hour_mean,
    SUM(CASE WHEN pm1_mean IS NOT NULL AND pm1_5min_n = 12 THEN 1 ELSE 0 END) AS pm1_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND pm1_mean IS NOT NULL
      THEN pm1_5min_n
      ELSE NULL
    END), 0)
  ) AS pm1_5min_profile,

    AVG(pm25_mean) AS pm25_mean,
    MIN(pm25_min) AS pm25_min,
    MAX(pm25_max) AS pm25_max,
    SUM(pm25_raw_n) AS pm25_raw_n,
    COUNT(pm25_mean) AS pm25_hours_n,
    SUM(pm25_5min_n) AS pm25_5min_n,
    AVG(CASE WHEN pm25_mean IS NOT NULL THEN pm25_5min_n ELSE NULL END) AS pm25_5min_per_hour_mean,
    SUM(CASE WHEN pm25_mean IS NOT NULL AND pm25_5min_n = 12 THEN 1 ELSE 0 END) AS pm25_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND pm25_mean IS NOT NULL
      THEN pm25_5min_n
      ELSE NULL
    END), 0)
  ) AS pm25_5min_profile,

    AVG(pm10_mean) AS pm10_mean,
    MIN(pm10_min) AS pm10_min,
    MAX(pm10_max) AS pm10_max,
    SUM(pm10_raw_n) AS pm10_raw_n,
    COUNT(pm10_mean) AS pm10_hours_n,
    SUM(pm10_5min_n) AS pm10_5min_n,
    AVG(CASE WHEN pm10_mean IS NOT NULL THEN pm10_5min_n ELSE NULL END) AS pm10_5min_per_hour_mean,
    SUM(CASE WHEN pm10_mean IS NOT NULL AND pm10_5min_n = 12 THEN 1 ELSE 0 END) AS pm10_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND pm10_mean IS NOT NULL
      THEN pm10_5min_n
      ELSE NULL
    END), 0)
  ) AS pm10_5min_profile,

    AVG(pc03_mean) AS pc03_mean,
    MIN(pc03_min) AS pc03_min,
    MAX(pc03_max) AS pc03_max,
    SUM(pc03_raw_n) AS pc03_raw_n,
    COUNT(pc03_mean) AS pc03_hours_n,
    SUM(pc03_5min_n) AS pc03_5min_n,
    AVG(CASE WHEN pc03_mean IS NOT NULL THEN pc03_5min_n ELSE NULL END) AS pc03_5min_per_hour_mean,
    SUM(CASE WHEN pc03_mean IS NOT NULL AND pc03_5min_n = 12 THEN 1 ELSE 0 END) AS pc03_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND pc03_mean IS NOT NULL
      THEN pc03_5min_n
      ELSE NULL
    END), 0)
  ) AS pc03_5min_profile,

    AVG(pc05_mean) AS pc05_mean,
    MIN(pc05_min) AS pc05_min,
    MAX(pc05_max) AS pc05_max,
    SUM(pc05_raw_n) AS pc05_raw_n,
    COUNT(pc05_mean) AS pc05_hours_n,
    SUM(pc05_5min_n) AS pc05_5min_n,
    AVG(CASE WHEN pc05_mean IS NOT NULL THEN pc05_5min_n ELSE NULL END) AS pc05_5min_per_hour_mean,
    SUM(CASE WHEN pc05_mean IS NOT NULL AND pc05_5min_n = 12 THEN 1 ELSE 0 END) AS pc05_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND pc05_mean IS NOT NULL
      THEN pc05_5min_n
      ELSE NULL
    END), 0)
  ) AS pc05_5min_profile,

    AVG(pc1_mean) AS pc1_mean,
    MIN(pc1_min) AS pc1_min,
    MAX(pc1_max) AS pc1_max,
    SUM(pc1_raw_n) AS pc1_raw_n,
    COUNT(pc1_mean) AS pc1_hours_n,
    SUM(pc1_5min_n) AS pc1_5min_n,
    AVG(CASE WHEN pc1_mean IS NOT NULL THEN pc1_5min_n ELSE NULL END) AS pc1_5min_per_hour_mean,
    SUM(CASE WHEN pc1_mean IS NOT NULL AND pc1_5min_n = 12 THEN 1 ELSE 0 END) AS pc1_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND pc1_mean IS NOT NULL
      THEN pc1_5min_n
      ELSE NULL
    END), 0)
  ) AS pc1_5min_profile,

    AVG(pc25_mean) AS pc25_mean,
    MIN(pc25_min) AS pc25_min,
    MAX(pc25_max) AS pc25_max,
    SUM(pc25_raw_n) AS pc25_raw_n,
    COUNT(pc25_mean) AS pc25_hours_n,
    SUM(pc25_5min_n) AS pc25_5min_n,
    AVG(CASE WHEN pc25_mean IS NOT NULL THEN pc25_5min_n ELSE NULL END) AS pc25_5min_per_hour_mean,
    SUM(CASE WHEN pc25_mean IS NOT NULL AND pc25_5min_n = 12 THEN 1 ELSE 0 END) AS pc25_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND pc25_mean IS NOT NULL
      THEN pc25_5min_n
      ELSE NULL
    END), 0)
  ) AS pc25_5min_profile,

    AVG(pc5_mean) AS pc5_mean,
    MIN(pc5_min) AS pc5_min,
    MAX(pc5_max) AS pc5_max,
    SUM(pc5_raw_n) AS pc5_raw_n,
    COUNT(pc5_mean) AS pc5_hours_n,
    SUM(pc5_5min_n) AS pc5_5min_n,
    AVG(CASE WHEN pc5_mean IS NOT NULL THEN pc5_5min_n ELSE NULL END) AS pc5_5min_per_hour_mean,
    SUM(CASE WHEN pc5_mean IS NOT NULL AND pc5_5min_n = 12 THEN 1 ELSE 0 END) AS pc5_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND pc5_mean IS NOT NULL
      THEN pc5_5min_n
      ELSE NULL
    END), 0)
  ) AS pc5_5min_profile,

    AVG(pc10_mean) AS pc10_mean,
    MIN(pc10_min) AS pc10_min,
    MAX(pc10_max) AS pc10_max,
    SUM(pc10_raw_n) AS pc10_raw_n,
    COUNT(pc10_mean) AS pc10_hours_n,
    SUM(pc10_5min_n) AS pc10_5min_n,
    AVG(CASE WHEN pc10_mean IS NOT NULL THEN pc10_5min_n ELSE NULL END) AS pc10_5min_per_hour_mean,
    SUM(CASE WHEN pc10_mean IS NOT NULL AND pc10_5min_n = 12 THEN 1 ELSE 0 END) AS pc10_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND pc10_mean IS NOT NULL
      THEN pc10_5min_n
      ELSE NULL
    END), 0)
  ) AS pc10_5min_profile,

    AVG(temperature_mean) AS temperature_mean,
    MIN(temperature_min) AS temperature_min,
    MAX(temperature_max) AS temperature_max,
    SUM(temperature_raw_n) AS temperature_raw_n,
    COUNT(temperature_mean) AS temperature_hours_n,
    SUM(temperature_5min_n) AS temperature_5min_n,
    AVG(CASE WHEN temperature_mean IS NOT NULL THEN temperature_5min_n ELSE NULL END) AS temperature_5min_per_hour_mean,
    SUM(CASE WHEN temperature_mean IS NOT NULL AND temperature_5min_n = 12 THEN 1 ELSE 0 END) AS temperature_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND temperature_mean IS NOT NULL
      THEN temperature_5min_n
      ELSE NULL
    END), 0)
  ) AS temperature_5min_profile,

    AVG(humidity_mean) AS humidity_mean,
    MIN(humidity_min) AS humidity_min,
    MAX(humidity_max) AS humidity_max,
    SUM(humidity_raw_n) AS humidity_raw_n,
    COUNT(humidity_mean) AS humidity_hours_n,
    SUM(humidity_5min_n) AS humidity_5min_n,
    AVG(CASE WHEN humidity_mean IS NOT NULL THEN humidity_5min_n ELSE NULL END) AS humidity_5min_per_hour_mean,
    SUM(CASE WHEN humidity_mean IS NOT NULL AND humidity_5min_n = 12 THEN 1 ELSE 0 END) AS humidity_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND humidity_mean IS NOT NULL
      THEN humidity_5min_n
      ELSE NULL
    END), 0)
  ) AS humidity_5min_profile,

    AVG(pressure_mean) AS pressure_mean,
    MIN(pressure_min) AS pressure_min,
    MAX(pressure_max) AS pressure_max,
    SUM(pressure_raw_n) AS pressure_raw_n,
    COUNT(pressure_mean) AS pressure_hours_n,
    SUM(pressure_5min_n) AS pressure_5min_n,
    AVG(CASE WHEN pressure_mean IS NOT NULL THEN pressure_5min_n ELSE NULL END) AS pressure_5min_per_hour_mean,
    SUM(CASE WHEN pressure_mean IS NOT NULL AND pressure_5min_n = 12 THEN 1 ELSE 0 END) AS pressure_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND pressure_mean IS NOT NULL
      THEN pressure_5min_n
      ELSE NULL
    END), 0)
  ) AS pressure_5min_profile,

    AVG(sound_mean) AS sound_mean,
    MIN(sound_min) AS sound_min,
    MAX(sound_max) AS sound_max,
    SUM(sound_raw_n) AS sound_raw_n,
    COUNT(sound_mean) AS sound_hours_n,
    SUM(sound_5min_n) AS sound_5min_n,
    AVG(CASE WHEN sound_mean IS NOT NULL THEN sound_5min_n ELSE NULL END) AS sound_5min_per_hour_mean,
    SUM(CASE WHEN sound_mean IS NOT NULL AND sound_5min_n = 12 THEN 1 ELSE 0 END) AS sound_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND sound_mean IS NOT NULL
      THEN sound_5min_n
      ELSE NULL
    END), 0)
  ) AS sound_5min_profile,

    AVG(uvb_mean) AS uvb_mean,
    MIN(uvb_min) AS uvb_min,
    MAX(uvb_max) AS uvb_max,
    SUM(uvb_raw_n) AS uvb_raw_n,
    COUNT(uvb_mean) AS uvb_hours_n,
    SUM(uvb_5min_n) AS uvb_5min_n,
    AVG(CASE WHEN uvb_mean IS NOT NULL THEN uvb_5min_n ELSE NULL END) AS uvb_5min_per_hour_mean,
    SUM(CASE WHEN uvb_mean IS NOT NULL AND uvb_5min_n = 12 THEN 1 ELSE 0 END) AS uvb_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND uvb_mean IS NOT NULL
      THEN uvb_5min_n
      ELSE NULL
    END), 0)
  ) AS uvb_5min_profile,

    AVG(light_mean) AS light_mean,
    MIN(light_min) AS light_min,
    MAX(light_max) AS light_max,
    SUM(light_raw_n) AS light_raw_n,
    COUNT(light_mean) AS light_hours_n,
    SUM(light_5min_n) AS light_5min_n,
    AVG(CASE WHEN light_mean IS NOT NULL THEN light_5min_n ELSE NULL END) AS light_5min_per_hour_mean,
    SUM(CASE WHEN light_mean IS NOT NULL AND light_5min_n = 12 THEN 1 ELSE 0 END) AS light_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND light_mean IS NOT NULL
      THEN light_5min_n
      ELSE NULL
    END), 0)
  ) AS light_5min_profile

  FROM myair_hourly

  GROUP BY
    userId,
    deviceId,
    firmware,
    DATE(bucket_hour);

END//


DELIMITER ;
