-- =========================================================
-- etl_myair_daily.sql
--
-- Materialized daily aggregation of myair_5min.
--
-- One row per device, firmware and calendar date.
--
-- Daily summaries are built directly from five-minute
-- intervals, rather than from hourly rows.
--
-- Temporal weighting:
--   each available five-minute interval contributes one
--   equally weighted value to the daily mean, regardless
--   of the number of raw readings represented by the
--   interval or by its hour.
--
-- For each measurement:
--   mean    : mean of available five-minute means
--   min     : minimum across five-minute minima
--   max     : maximum across five-minute maxima
--   raw_n   : total valid raw readings represented
--   5min_n  : five-minute intervals with a valid mean
--   hours_n : distinct hours containing a valid mean
--
-- General coverage:
--   records_n  : total tidy records represented
--   five_min_n : observed five-minute intervals, max 288
--   hours_n    : distinct observed hours, max 24
--
-- No minimum coverage threshold is applied here. A rule
-- such as hours_n >= 16 can be applied downstream.
-- =========================================================


CREATE TABLE IF NOT EXISTS myair_daily (

  userId   BIGINT       NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  firmware VARCHAR(128) NOT NULL,

  date DATE NOT NULL,

  records_n  SMALLINT UNSIGNED NOT NULL,
  five_min_n SMALLINT UNSIGNED NOT NULL,
  hours_n    TINYINT UNSIGNED  NOT NULL,

  pm1_mean    DOUBLE NULL,
  pm1_min     DOUBLE NULL,
  pm1_max     DOUBLE NULL,
  pm1_raw_n   SMALLINT UNSIGNED NOT NULL,
  pm1_5min_n  SMALLINT UNSIGNED NOT NULL,
  pm1_hours_n TINYINT UNSIGNED NOT NULL,

  pm25_mean    DOUBLE NULL,
  pm25_min     DOUBLE NULL,
  pm25_max     DOUBLE NULL,
  pm25_raw_n   SMALLINT UNSIGNED NOT NULL,
  pm25_5min_n  SMALLINT UNSIGNED NOT NULL,
  pm25_hours_n TINYINT UNSIGNED NOT NULL,

  pm10_mean    DOUBLE NULL,
  pm10_min     DOUBLE NULL,
  pm10_max     DOUBLE NULL,
  pm10_raw_n   SMALLINT UNSIGNED NOT NULL,
  pm10_5min_n  SMALLINT UNSIGNED NOT NULL,
  pm10_hours_n TINYINT UNSIGNED NOT NULL,

  pc03_mean    DOUBLE NULL,
  pc03_min     DOUBLE NULL,
  pc03_max     DOUBLE NULL,
  pc03_raw_n   SMALLINT UNSIGNED NOT NULL,
  pc03_5min_n  SMALLINT UNSIGNED NOT NULL,
  pc03_hours_n TINYINT UNSIGNED NOT NULL,

  pc05_mean    DOUBLE NULL,
  pc05_min     DOUBLE NULL,
  pc05_max     DOUBLE NULL,
  pc05_raw_n   SMALLINT UNSIGNED NOT NULL,
  pc05_5min_n  SMALLINT UNSIGNED NOT NULL,
  pc05_hours_n TINYINT UNSIGNED NOT NULL,

  pc1_mean    DOUBLE NULL,
  pc1_min     DOUBLE NULL,
  pc1_max     DOUBLE NULL,
  pc1_raw_n   SMALLINT UNSIGNED NOT NULL,
  pc1_5min_n  SMALLINT UNSIGNED NOT NULL,
  pc1_hours_n TINYINT UNSIGNED NOT NULL,

  pc25_mean    DOUBLE NULL,
  pc25_min     DOUBLE NULL,
  pc25_max     DOUBLE NULL,
  pc25_raw_n   SMALLINT UNSIGNED NOT NULL,
  pc25_5min_n  SMALLINT UNSIGNED NOT NULL,
  pc25_hours_n TINYINT UNSIGNED NOT NULL,

  pc5_mean    DOUBLE NULL,
  pc5_min     DOUBLE NULL,
  pc5_max     DOUBLE NULL,
  pc5_raw_n   SMALLINT UNSIGNED NOT NULL,
  pc5_5min_n  SMALLINT UNSIGNED NOT NULL,
  pc5_hours_n TINYINT UNSIGNED NOT NULL,

  pc10_mean    DOUBLE NULL,
  pc10_min     DOUBLE NULL,
  pc10_max     DOUBLE NULL,
  pc10_raw_n   SMALLINT UNSIGNED NOT NULL,
  pc10_5min_n  SMALLINT UNSIGNED NOT NULL,
  pc10_hours_n TINYINT UNSIGNED NOT NULL,

  temperature_mean    DOUBLE NULL,
  temperature_min     DOUBLE NULL,
  temperature_max     DOUBLE NULL,
  temperature_raw_n   SMALLINT UNSIGNED NOT NULL,
  temperature_5min_n  SMALLINT UNSIGNED NOT NULL,
  temperature_hours_n TINYINT UNSIGNED NOT NULL,

  humidity_mean    DOUBLE NULL,
  humidity_min     DOUBLE NULL,
  humidity_max     DOUBLE NULL,
  humidity_raw_n   SMALLINT UNSIGNED NOT NULL,
  humidity_5min_n  SMALLINT UNSIGNED NOT NULL,
  humidity_hours_n TINYINT UNSIGNED NOT NULL,

  pressure_mean    DOUBLE NULL,
  pressure_min     DOUBLE NULL,
  pressure_max     DOUBLE NULL,
  pressure_raw_n   SMALLINT UNSIGNED NOT NULL,
  pressure_5min_n  SMALLINT UNSIGNED NOT NULL,
  pressure_hours_n TINYINT UNSIGNED NOT NULL,

  sound_mean    DOUBLE NULL,
  sound_min     DOUBLE NULL,
  sound_max     DOUBLE NULL,
  sound_raw_n   SMALLINT UNSIGNED NOT NULL,
  sound_5min_n  SMALLINT UNSIGNED NOT NULL,
  sound_hours_n TINYINT UNSIGNED NOT NULL,

  uvb_mean    DOUBLE NULL,
  uvb_min     DOUBLE NULL,
  uvb_max     DOUBLE NULL,
  uvb_raw_n   SMALLINT UNSIGNED NOT NULL,
  uvb_5min_n  SMALLINT UNSIGNED NOT NULL,
  uvb_hours_n TINYINT UNSIGNED NOT NULL,

  light_mean    DOUBLE NULL,
  light_min     DOUBLE NULL,
  light_max     DOUBLE NULL,
  light_raw_n   SMALLINT UNSIGNED NOT NULL,
  light_5min_n  SMALLINT UNSIGNED NOT NULL,
  light_hours_n TINYINT UNSIGNED NOT NULL,

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

    records_n  SMALLINT UNSIGNED NOT NULL,
    five_min_n SMALLINT UNSIGNED NOT NULL,
    hours_n    TINYINT UNSIGNED  NOT NULL,

    pm1_mean    DOUBLE NULL,
    pm1_min     DOUBLE NULL,
    pm1_max     DOUBLE NULL,
    pm1_raw_n   SMALLINT UNSIGNED NOT NULL,
    pm1_5min_n  SMALLINT UNSIGNED NOT NULL,
    pm1_hours_n TINYINT UNSIGNED NOT NULL,

    pm25_mean    DOUBLE NULL,
    pm25_min     DOUBLE NULL,
    pm25_max     DOUBLE NULL,
    pm25_raw_n   SMALLINT UNSIGNED NOT NULL,
    pm25_5min_n  SMALLINT UNSIGNED NOT NULL,
    pm25_hours_n TINYINT UNSIGNED NOT NULL,

    pm10_mean    DOUBLE NULL,
    pm10_min     DOUBLE NULL,
    pm10_max     DOUBLE NULL,
    pm10_raw_n   SMALLINT UNSIGNED NOT NULL,
    pm10_5min_n  SMALLINT UNSIGNED NOT NULL,
    pm10_hours_n TINYINT UNSIGNED NOT NULL,

    pc03_mean    DOUBLE NULL,
    pc03_min     DOUBLE NULL,
    pc03_max     DOUBLE NULL,
    pc03_raw_n   SMALLINT UNSIGNED NOT NULL,
    pc03_5min_n  SMALLINT UNSIGNED NOT NULL,
    pc03_hours_n TINYINT UNSIGNED NOT NULL,

    pc05_mean    DOUBLE NULL,
    pc05_min     DOUBLE NULL,
    pc05_max     DOUBLE NULL,
    pc05_raw_n   SMALLINT UNSIGNED NOT NULL,
    pc05_5min_n  SMALLINT UNSIGNED NOT NULL,
    pc05_hours_n TINYINT UNSIGNED NOT NULL,

    pc1_mean    DOUBLE NULL,
    pc1_min     DOUBLE NULL,
    pc1_max     DOUBLE NULL,
    pc1_raw_n   SMALLINT UNSIGNED NOT NULL,
    pc1_5min_n  SMALLINT UNSIGNED NOT NULL,
    pc1_hours_n TINYINT UNSIGNED NOT NULL,

    pc25_mean    DOUBLE NULL,
    pc25_min     DOUBLE NULL,
    pc25_max     DOUBLE NULL,
    pc25_raw_n   SMALLINT UNSIGNED NOT NULL,
    pc25_5min_n  SMALLINT UNSIGNED NOT NULL,
    pc25_hours_n TINYINT UNSIGNED NOT NULL,

    pc5_mean    DOUBLE NULL,
    pc5_min     DOUBLE NULL,
    pc5_max     DOUBLE NULL,
    pc5_raw_n   SMALLINT UNSIGNED NOT NULL,
    pc5_5min_n  SMALLINT UNSIGNED NOT NULL,
    pc5_hours_n TINYINT UNSIGNED NOT NULL,

    pc10_mean    DOUBLE NULL,
    pc10_min     DOUBLE NULL,
    pc10_max     DOUBLE NULL,
    pc10_raw_n   SMALLINT UNSIGNED NOT NULL,
    pc10_5min_n  SMALLINT UNSIGNED NOT NULL,
    pc10_hours_n TINYINT UNSIGNED NOT NULL,

    temperature_mean    DOUBLE NULL,
    temperature_min     DOUBLE NULL,
    temperature_max     DOUBLE NULL,
    temperature_raw_n   SMALLINT UNSIGNED NOT NULL,
    temperature_5min_n  SMALLINT UNSIGNED NOT NULL,
    temperature_hours_n TINYINT UNSIGNED NOT NULL,

    humidity_mean    DOUBLE NULL,
    humidity_min     DOUBLE NULL,
    humidity_max     DOUBLE NULL,
    humidity_raw_n   SMALLINT UNSIGNED NOT NULL,
    humidity_5min_n  SMALLINT UNSIGNED NOT NULL,
    humidity_hours_n TINYINT UNSIGNED NOT NULL,

    pressure_mean    DOUBLE NULL,
    pressure_min     DOUBLE NULL,
    pressure_max     DOUBLE NULL,
    pressure_raw_n   SMALLINT UNSIGNED NOT NULL,
    pressure_5min_n  SMALLINT UNSIGNED NOT NULL,
    pressure_hours_n TINYINT UNSIGNED NOT NULL,

    sound_mean    DOUBLE NULL,
    sound_min     DOUBLE NULL,
    sound_max     DOUBLE NULL,
    sound_raw_n   SMALLINT UNSIGNED NOT NULL,
    sound_5min_n  SMALLINT UNSIGNED NOT NULL,
    sound_hours_n TINYINT UNSIGNED NOT NULL,

    uvb_mean    DOUBLE NULL,
    uvb_min     DOUBLE NULL,
    uvb_max     DOUBLE NULL,
    uvb_raw_n   SMALLINT UNSIGNED NOT NULL,
    uvb_5min_n  SMALLINT UNSIGNED NOT NULL,
    uvb_hours_n TINYINT UNSIGNED NOT NULL,

    light_mean    DOUBLE NULL,
    light_min     DOUBLE NULL,
    light_max     DOUBLE NULL,
    light_raw_n   SMALLINT UNSIGNED NOT NULL,
    light_5min_n  SMALLINT UNSIGNED NOT NULL,
    light_hours_n TINYINT UNSIGNED NOT NULL,

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
    five_min_n,
    hours_n,

    pm1_mean,
    pm1_min,
    pm1_max,
    pm1_raw_n,
    pm1_5min_n,
    pm1_hours_n,

    pm25_mean,
    pm25_min,
    pm25_max,
    pm25_raw_n,
    pm25_5min_n,
    pm25_hours_n,

    pm10_mean,
    pm10_min,
    pm10_max,
    pm10_raw_n,
    pm10_5min_n,
    pm10_hours_n,

    pc03_mean,
    pc03_min,
    pc03_max,
    pc03_raw_n,
    pc03_5min_n,
    pc03_hours_n,

    pc05_mean,
    pc05_min,
    pc05_max,
    pc05_raw_n,
    pc05_5min_n,
    pc05_hours_n,

    pc1_mean,
    pc1_min,
    pc1_max,
    pc1_raw_n,
    pc1_5min_n,
    pc1_hours_n,

    pc25_mean,
    pc25_min,
    pc25_max,
    pc25_raw_n,
    pc25_5min_n,
    pc25_hours_n,

    pc5_mean,
    pc5_min,
    pc5_max,
    pc5_raw_n,
    pc5_5min_n,
    pc5_hours_n,

    pc10_mean,
    pc10_min,
    pc10_max,
    pc10_raw_n,
    pc10_5min_n,
    pc10_hours_n,

    temperature_mean,
    temperature_min,
    temperature_max,
    temperature_raw_n,
    temperature_5min_n,
    temperature_hours_n,

    humidity_mean,
    humidity_min,
    humidity_max,
    humidity_raw_n,
    humidity_5min_n,
    humidity_hours_n,

    pressure_mean,
    pressure_min,
    pressure_max,
    pressure_raw_n,
    pressure_5min_n,
    pressure_hours_n,

    sound_mean,
    sound_min,
    sound_max,
    sound_raw_n,
    sound_5min_n,
    sound_hours_n,

    uvb_mean,
    uvb_min,
    uvb_max,
    uvb_raw_n,
    uvb_5min_n,
    uvb_hours_n,

    light_mean,
    light_min,
    light_max,
    light_raw_n,
    light_5min_n,
    light_hours_n
  )

  SELECT
    userId,
    deviceId,
    firmware,
    date,

    SUM(records_n) AS records_n,
    COUNT(*) AS five_min_n,
    COUNT(DISTINCT hour) AS hours_n,

    AVG(pm1_mean) AS pm1_mean,
    MIN(pm1_min) AS pm1_min,
    MAX(pm1_max) AS pm1_max,
    SUM(pm1_raw_n) AS pm1_raw_n,
    COUNT(pm1_mean) AS pm1_5min_n,
    COUNT(DISTINCT CASE,
      WHEN pm1_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS pm1_hours_n,

    AVG(pm25_mean) AS pm25_mean,
    MIN(pm25_min) AS pm25_min,
    MAX(pm25_max) AS pm25_max,
    SUM(pm25_raw_n) AS pm25_raw_n,
    COUNT(pm25_mean) AS pm25_5min_n,
    COUNT(DISTINCT CASE,
      WHEN pm25_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS pm25_hours_n,

    AVG(pm10_mean) AS pm10_mean,
    MIN(pm10_min) AS pm10_min,
    MAX(pm10_max) AS pm10_max,
    SUM(pm10_raw_n) AS pm10_raw_n,
    COUNT(pm10_mean) AS pm10_5min_n,
    COUNT(DISTINCT CASE,
      WHEN pm10_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS pm10_hours_n,

    AVG(pc03_mean) AS pc03_mean,
    MIN(pc03_min) AS pc03_min,
    MAX(pc03_max) AS pc03_max,
    SUM(pc03_raw_n) AS pc03_raw_n,
    COUNT(pc03_mean) AS pc03_5min_n,
    COUNT(DISTINCT CASE,
      WHEN pc03_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS pc03_hours_n,

    AVG(pc05_mean) AS pc05_mean,
    MIN(pc05_min) AS pc05_min,
    MAX(pc05_max) AS pc05_max,
    SUM(pc05_raw_n) AS pc05_raw_n,
    COUNT(pc05_mean) AS pc05_5min_n,
    COUNT(DISTINCT CASE,
      WHEN pc05_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS pc05_hours_n,

    AVG(pc1_mean) AS pc1_mean,
    MIN(pc1_min) AS pc1_min,
    MAX(pc1_max) AS pc1_max,
    SUM(pc1_raw_n) AS pc1_raw_n,
    COUNT(pc1_mean) AS pc1_5min_n,
    COUNT(DISTINCT CASE,
      WHEN pc1_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS pc1_hours_n,

    AVG(pc25_mean) AS pc25_mean,
    MIN(pc25_min) AS pc25_min,
    MAX(pc25_max) AS pc25_max,
    SUM(pc25_raw_n) AS pc25_raw_n,
    COUNT(pc25_mean) AS pc25_5min_n,
    COUNT(DISTINCT CASE,
      WHEN pc25_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS pc25_hours_n,

    AVG(pc5_mean) AS pc5_mean,
    MIN(pc5_min) AS pc5_min,
    MAX(pc5_max) AS pc5_max,
    SUM(pc5_raw_n) AS pc5_raw_n,
    COUNT(pc5_mean) AS pc5_5min_n,
    COUNT(DISTINCT CASE,
      WHEN pc5_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS pc5_hours_n,

    AVG(pc10_mean) AS pc10_mean,
    MIN(pc10_min) AS pc10_min,
    MAX(pc10_max) AS pc10_max,
    SUM(pc10_raw_n) AS pc10_raw_n,
    COUNT(pc10_mean) AS pc10_5min_n,
    COUNT(DISTINCT CASE,
      WHEN pc10_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS pc10_hours_n,

    AVG(temperature_mean) AS temperature_mean,
    MIN(temperature_min) AS temperature_min,
    MAX(temperature_max) AS temperature_max,
    SUM(temperature_raw_n) AS temperature_raw_n,
    COUNT(temperature_mean) AS temperature_5min_n,
    COUNT(DISTINCT CASE,
      WHEN temperature_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS temperature_hours_n,

    AVG(humidity_mean) AS humidity_mean,
    MIN(humidity_min) AS humidity_min,
    MAX(humidity_max) AS humidity_max,
    SUM(humidity_raw_n) AS humidity_raw_n,
    COUNT(humidity_mean) AS humidity_5min_n,
    COUNT(DISTINCT CASE,
      WHEN humidity_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS humidity_hours_n,

    AVG(pressure_mean) AS pressure_mean,
    MIN(pressure_min) AS pressure_min,
    MAX(pressure_max) AS pressure_max,
    SUM(pressure_raw_n) AS pressure_raw_n,
    COUNT(pressure_mean) AS pressure_5min_n,
    COUNT(DISTINCT CASE,
      WHEN pressure_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS pressure_hours_n,

    AVG(sound_mean) AS sound_mean,
    MIN(sound_min) AS sound_min,
    MAX(sound_max) AS sound_max,
    SUM(sound_raw_n) AS sound_raw_n,
    COUNT(sound_mean) AS sound_5min_n,
    COUNT(DISTINCT CASE,
      WHEN sound_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS sound_hours_n,

    AVG(uvb_mean) AS uvb_mean,
    MIN(uvb_min) AS uvb_min,
    MAX(uvb_max) AS uvb_max,
    SUM(uvb_raw_n) AS uvb_raw_n,
    COUNT(uvb_mean) AS uvb_5min_n,
    COUNT(DISTINCT CASE,
      WHEN uvb_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS uvb_hours_n,

    AVG(light_mean) AS light_mean,
    MIN(light_min) AS light_min,
    MAX(light_max) AS light_max,
    SUM(light_raw_n) AS light_raw_n,
    COUNT(light_mean) AS light_5min_n,
    COUNT(DISTINCT CASE,
      WHEN light_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS light_hours_n

  FROM myair_5min

  GROUP BY
    userId,
    deviceId,
    firmware,
    date;

END//


DELIMITER ;
