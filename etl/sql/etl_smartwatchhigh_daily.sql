-- =========================================================
-- etl_smartwatchhigh_daily.sql
--
-- Materialized daily aggregation of smartwatchhigh_5min.
--
-- One row per device, firmware and calendar date.
-- Daily summaries are built directly from five-minute
-- intervals so every observed interval receives equal
-- temporal weight.
--
-- Continuous measurements store:
--   mean    : mean of available five-minute means
--   min     : minimum across five-minute minima
--   max     : maximum across five-minute maxima
--   raw_n   : total valid raw readings represented
--   5min_n  : five-minute intervals with a valid mean
--   hours_n : distinct hours containing a valid mean
--
-- sleeprate is categorical. Counts are summed across
-- five-minute intervals and no arithmetic mean is computed.
--
-- No minimum coverage threshold is applied here.
-- =========================================================


CREATE TABLE IF NOT EXISTS smartwatchhigh_daily (

  userId   BIGINT       NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  firmware VARCHAR(128) NOT NULL,

  date DATE NOT NULL,

  records_n  SMALLINT UNSIGNED NOT NULL,
  five_min_n SMALLINT UNSIGNED NOT NULL,
  hours_n    TINYINT UNSIGNED  NOT NULL,

  heartrate_mean    DOUBLE NULL,
  heartrate_min     DOUBLE NULL,
  heartrate_max     DOUBLE NULL,
  heartrate_raw_n   SMALLINT UNSIGNED NOT NULL,
  heartrate_5min_n  SMALLINT UNSIGNED NOT NULL,
  heartrate_hours_n TINYINT UNSIGNED NOT NULL,

  oxygens_mean    DOUBLE NULL,
  oxygens_min     DOUBLE NULL,
  oxygens_max     DOUBLE NULL,
  oxygens_raw_n   SMALLINT UNSIGNED NOT NULL,
  oxygens_5min_n  SMALLINT UNSIGNED NOT NULL,
  oxygens_hours_n TINYINT UNSIGNED NOT NULL,

  breathrate_mean    DOUBLE NULL,
  breathrate_min     DOUBLE NULL,
  breathrate_max     DOUBLE NULL,
  breathrate_raw_n   SMALLINT UNSIGNED NOT NULL,
  breathrate_5min_n  SMALLINT UNSIGNED NOT NULL,
  breathrate_hours_n TINYINT UNSIGNED NOT NULL,

  sleeprate_raw_n   SMALLINT UNSIGNED NOT NULL,
  sleeprate_5min_n  SMALLINT UNSIGNED NOT NULL,
  sleeprate_hours_n TINYINT UNSIGNED NOT NULL,
  sleeprate_1_n     SMALLINT UNSIGNED NOT NULL,
  sleeprate_2_n     SMALLINT UNSIGNED NOT NULL,
  sleeprate_3_n     SMALLINT UNSIGNED NOT NULL,
  sleeprate_4_n     SMALLINT UNSIGNED NOT NULL,

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

  -- Full rebuild of the materialized daily table
  DROP TABLE IF EXISTS smartwatchhigh_daily;

  CREATE TABLE smartwatchhigh_daily (

    userId   BIGINT       NOT NULL,
    deviceId VARCHAR(128) NOT NULL,
    firmware VARCHAR(128) NOT NULL,

    date DATE NOT NULL,

    records_n  SMALLINT UNSIGNED NOT NULL,
    five_min_n SMALLINT UNSIGNED NOT NULL,
    hours_n    TINYINT UNSIGNED  NOT NULL,

    heartrate_mean    DOUBLE NULL,
    heartrate_min     DOUBLE NULL,
    heartrate_max     DOUBLE NULL,
    heartrate_raw_n   SMALLINT UNSIGNED NOT NULL,
    heartrate_5min_n  SMALLINT UNSIGNED NOT NULL,
    heartrate_hours_n TINYINT UNSIGNED NOT NULL,

    oxygens_mean    DOUBLE NULL,
    oxygens_min     DOUBLE NULL,
    oxygens_max     DOUBLE NULL,
    oxygens_raw_n   SMALLINT UNSIGNED NOT NULL,
    oxygens_5min_n  SMALLINT UNSIGNED NOT NULL,
    oxygens_hours_n TINYINT UNSIGNED NOT NULL,

    breathrate_mean    DOUBLE NULL,
    breathrate_min     DOUBLE NULL,
    breathrate_max     DOUBLE NULL,
    breathrate_raw_n   SMALLINT UNSIGNED NOT NULL,
    breathrate_5min_n  SMALLINT UNSIGNED NOT NULL,
    breathrate_hours_n TINYINT UNSIGNED NOT NULL,

    sleeprate_raw_n   SMALLINT UNSIGNED NOT NULL,
    sleeprate_5min_n  SMALLINT UNSIGNED NOT NULL,
    sleeprate_hours_n TINYINT UNSIGNED NOT NULL,
    sleeprate_1_n     SMALLINT UNSIGNED NOT NULL,
    sleeprate_2_n     SMALLINT UNSIGNED NOT NULL,
    sleeprate_3_n     SMALLINT UNSIGNED NOT NULL,
    sleeprate_4_n     SMALLINT UNSIGNED NOT NULL,

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
    five_min_n,
    hours_n,

    heartrate_mean,
    heartrate_min,
    heartrate_max,
    heartrate_raw_n,
    heartrate_5min_n,
    heartrate_hours_n,

    oxygens_mean,
    oxygens_min,
    oxygens_max,
    oxygens_raw_n,
    oxygens_5min_n,
    oxygens_hours_n,

    breathrate_mean,
    breathrate_min,
    breathrate_max,
    breathrate_raw_n,
    breathrate_5min_n,
    breathrate_hours_n,

    sleeprate_raw_n,
    sleeprate_5min_n,
    sleeprate_hours_n,
    sleeprate_1_n,
    sleeprate_2_n,
    sleeprate_3_n,
    sleeprate_4_n
  )

  SELECT
    userId,
    deviceId,
    firmware,
    date,

    SUM(records_n) AS records_n,
    COUNT(*) AS five_min_n,
    COUNT(DISTINCT hour) AS hours_n,

    AVG(heartrate_mean) AS heartrate_mean,
    MIN(heartrate_min) AS heartrate_min,
    MAX(heartrate_max) AS heartrate_max,
    SUM(heartrate_raw_n) AS heartrate_raw_n,
    COUNT(heartrate_mean) AS heartrate_5min_n,
    COUNT(DISTINCT CASE,
      WHEN heartrate_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS heartrate_hours_n,

    AVG(oxygens_mean) AS oxygens_mean,
    MIN(oxygens_min) AS oxygens_min,
    MAX(oxygens_max) AS oxygens_max,
    SUM(oxygens_raw_n) AS oxygens_raw_n,
    COUNT(oxygens_mean) AS oxygens_5min_n,
    COUNT(DISTINCT CASE,
      WHEN oxygens_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS oxygens_hours_n,

    AVG(breathrate_mean) AS breathrate_mean,
    MIN(breathrate_min) AS breathrate_min,
    MAX(breathrate_max) AS breathrate_max,
    SUM(breathrate_raw_n) AS breathrate_raw_n,
    COUNT(breathrate_mean) AS breathrate_5min_n,
    COUNT(DISTINCT CASE,
      WHEN breathrate_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS breathrate_hours_n,

    SUM(sleeprate_raw_n) AS sleeprate_raw_n,
    SUM(CASE,
      WHEN sleeprate_raw_n > 0 THEN 1,
      ELSE 0,
    END) AS sleeprate_5min_n,
    COUNT(DISTINCT CASE,
      WHEN sleeprate_raw_n > 0 THEN hour,
      ELSE NULL,
    END) AS sleeprate_hours_n,
    SUM(sleeprate_1_n) AS sleeprate_1_n,
    SUM(sleeprate_2_n) AS sleeprate_2_n,
    SUM(sleeprate_3_n) AS sleeprate_3_n,
    SUM(sleeprate_4_n) AS sleeprate_4_n

  FROM smartwatchhigh_5min

  GROUP BY
    userId,
    deviceId,
    firmware,
    date;

END//


DELIMITER ;
