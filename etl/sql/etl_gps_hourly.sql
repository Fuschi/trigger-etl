-- =========================================================
-- etl_gps_hourly.sql
--
-- Materialized hourly aggregation of gps_5min.
--
-- One row per device, firmware and fixed hourly bucket.
-- Each available five-minute interval receives equal
-- temporal weight in hourly coordinate and accuracy means.
--
-- Coordinates remain available independently of accuracy.
-- =========================================================


CREATE TABLE IF NOT EXISTS gps_hourly (

  userId   BIGINT       NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  firmware VARCHAR(128) NOT NULL,

  bucket_hour DATETIME NOT NULL,

  records_n  SMALLINT UNSIGNED NOT NULL,
  five_min_n TINYINT UNSIGNED  NOT NULL,

  position_raw_n  SMALLINT UNSIGNED NOT NULL,
  position_5min_n TINYINT UNSIGNED NOT NULL,

  longitude_mean DOUBLE NULL,
  longitude_min  DOUBLE NULL,
  longitude_max  DOUBLE NULL,

  latitude_mean DOUBLE NULL,
  latitude_min  DOUBLE NULL,
  latitude_max  DOUBLE NULL,

  accuracy_mean   DOUBLE NULL,
  accuracy_min    DOUBLE NULL,
  accuracy_max    DOUBLE NULL,
  accuracy_raw_n  SMALLINT UNSIGNED NOT NULL,
  accuracy_5min_n TINYINT UNSIGNED NOT NULL,

  PRIMARY KEY (
    deviceId,
    firmware,
    bucket_hour
  ),

  INDEX idx_gps_hourly_user_bucket (
    userId,
    bucket_hour
  ),

  INDEX idx_gps_hourly_bucket (
    bucket_hour
  )

) ENGINE=InnoDB;


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_gps_hourly()
BEGIN

  DROP TABLE IF EXISTS gps_hourly;

  CREATE TABLE gps_hourly (

    userId   BIGINT       NOT NULL,
    deviceId VARCHAR(128) NOT NULL,
    firmware VARCHAR(128) NOT NULL,

    bucket_hour DATETIME NOT NULL,

    records_n  SMALLINT UNSIGNED NOT NULL,
    five_min_n TINYINT UNSIGNED  NOT NULL,

    position_raw_n  SMALLINT UNSIGNED NOT NULL,
    position_5min_n TINYINT UNSIGNED NOT NULL,

    longitude_mean DOUBLE NULL,
    longitude_min  DOUBLE NULL,
    longitude_max  DOUBLE NULL,

    latitude_mean DOUBLE NULL,
    latitude_min  DOUBLE NULL,
    latitude_max  DOUBLE NULL,

    accuracy_mean   DOUBLE NULL,
    accuracy_min    DOUBLE NULL,
    accuracy_max    DOUBLE NULL,
    accuracy_raw_n  SMALLINT UNSIGNED NOT NULL,
    accuracy_5min_n TINYINT UNSIGNED NOT NULL,

    PRIMARY KEY (
      deviceId,
      firmware,
      bucket_hour
    ),

    INDEX idx_gps_hourly_user_bucket (
      userId,
      bucket_hour
    ),

    INDEX idx_gps_hourly_bucket (
      bucket_hour
    )

  ) ENGINE=InnoDB;


  INSERT INTO gps_hourly (
    userId,
    deviceId,
    firmware,
    bucket_hour,

    records_n,
    five_min_n,

    position_raw_n,
    position_5min_n,

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
    accuracy_5min_n
  )

  WITH hourly_source AS (
    SELECT
      f.*,

      TIMESTAMP(
        DATE(f.bucket_5min),
        MAKETIME(HOUR(f.bucket_5min), 0, 0)
      ) AS bucket_hour

    FROM gps_5min AS f
  )

  SELECT
    userId,
    deviceId,
    firmware,
    bucket_hour,

    SUM(records_n) AS records_n,
    COUNT(*)       AS five_min_n,

    SUM(position_raw_n)  AS position_raw_n,
    COUNT(longitude_mean) AS position_5min_n,

    AVG(longitude_mean) AS longitude_mean,
    MIN(longitude_min)  AS longitude_min,
    MAX(longitude_max)  AS longitude_max,

    AVG(latitude_mean) AS latitude_mean,
    MIN(latitude_min)  AS latitude_min,
    MAX(latitude_max)  AS latitude_max,

    AVG(accuracy_mean)   AS accuracy_mean,
    MIN(accuracy_min)    AS accuracy_min,
    MAX(accuracy_max)    AS accuracy_max,
    SUM(accuracy_raw_n)  AS accuracy_raw_n,
    COUNT(accuracy_mean) AS accuracy_5min_n

  FROM hourly_source

  GROUP BY
    userId,
    deviceId,
    firmware,
    bucket_hour;

END//


DELIMITER ;
