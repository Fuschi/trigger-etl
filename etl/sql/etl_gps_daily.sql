-- =========================================================
-- etl_gps_daily.sql
--
-- Materialized daily aggregation of gps_5min.
--
-- One row per device, firmware and calendar date.
-- Daily coordinate and accuracy means are calculated
-- directly from five-minute means, giving every available
-- interval equal temporal weight.
--
-- Coordinates remain available independently of accuracy.
--
-- Coverage fields distinguish:
--   raw observations represented
--   valid five-minute intervals
--   distinct observed hours
--
-- No minimum coverage threshold is applied here.
-- =========================================================


CREATE TABLE IF NOT EXISTS gps_daily (

  userId   BIGINT       NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  firmware VARCHAR(128) NOT NULL,

  date DATE NOT NULL,

  records_n  SMALLINT UNSIGNED NOT NULL,
  five_min_n SMALLINT UNSIGNED NOT NULL,
  hours_n    TINYINT UNSIGNED  NOT NULL,

  position_raw_n   SMALLINT UNSIGNED NOT NULL,
  position_5min_n  SMALLINT UNSIGNED NOT NULL,
  position_hours_n TINYINT UNSIGNED NOT NULL,

  longitude_mean DOUBLE NULL,
  longitude_min  DOUBLE NULL,
  longitude_max  DOUBLE NULL,

  latitude_mean DOUBLE NULL,
  latitude_min  DOUBLE NULL,
  latitude_max  DOUBLE NULL,

  accuracy_mean    DOUBLE NULL,
  accuracy_min     DOUBLE NULL,
  accuracy_max     DOUBLE NULL,
  accuracy_raw_n   SMALLINT UNSIGNED NOT NULL,
  accuracy_5min_n  SMALLINT UNSIGNED NOT NULL,
  accuracy_hours_n TINYINT UNSIGNED NOT NULL,

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

  -- Full rebuild of the materialized daily table
  DROP TABLE IF EXISTS gps_daily;

  CREATE TABLE gps_daily (

    userId   BIGINT       NOT NULL,
    deviceId VARCHAR(128) NOT NULL,
    firmware VARCHAR(128) NOT NULL,

    date DATE NOT NULL,

    records_n  SMALLINT UNSIGNED NOT NULL,
    five_min_n SMALLINT UNSIGNED NOT NULL,
    hours_n    TINYINT UNSIGNED  NOT NULL,

    position_raw_n   SMALLINT UNSIGNED NOT NULL,
    position_5min_n  SMALLINT UNSIGNED NOT NULL,
    position_hours_n TINYINT UNSIGNED NOT NULL,

    longitude_mean DOUBLE NULL,
    longitude_min  DOUBLE NULL,
    longitude_max  DOUBLE NULL,

    latitude_mean DOUBLE NULL,
    latitude_min  DOUBLE NULL,
    latitude_max  DOUBLE NULL,

    accuracy_mean    DOUBLE NULL,
    accuracy_min     DOUBLE NULL,
    accuracy_max     DOUBLE NULL,
    accuracy_raw_n   SMALLINT UNSIGNED NOT NULL,
    accuracy_5min_n  SMALLINT UNSIGNED NOT NULL,
    accuracy_hours_n TINYINT UNSIGNED NOT NULL,

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
    five_min_n,
    hours_n,

    position_raw_n,
    position_5min_n,
    position_hours_n,

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
    accuracy_5min_n,
    accuracy_hours_n
  )

  SELECT
    userId,
    deviceId,
    firmware,
    DATE(bucket_5min) AS date,

    SUM(records_n) AS records_n,
    COUNT(*) AS five_min_n,
    COUNT(DISTINCT HOUR(bucket_5min)) AS hours_n,

    SUM(position_raw_n) AS position_raw_n,
    COUNT(longitude_mean) AS position_5min_n,
    COUNT(DISTINCT CASE,
      WHEN longitude_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS position_hours_n,

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
    COUNT(accuracy_mean) AS accuracy_5min_n,
    COUNT(DISTINCT CASE,
      WHEN accuracy_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS accuracy_hours_n

  FROM gps_5min

  GROUP BY
    userId,
    deviceId,
    firmware,
    DATE(bucket_5min);

END//


DELIMITER ;
