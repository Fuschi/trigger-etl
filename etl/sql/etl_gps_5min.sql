-- =========================================================
-- etl_gps_5min.sql
--
-- Materialized five-minute aggregation of gps_tidy.
--
-- One row per device, firmware and fixed five-minute bucket.
--
-- Coordinate statistics:
--   mean : arithmetic mean within the interval
--   min  : minimum coordinate value
--   max  : maximum coordinate value
--
-- Counts:
--   records_n:
--     total gps_tidy records in the bucket
--
--   position_raw_n:
--     records containing a valid longitude-latitude pair
--
--   accuracy_raw_n:
--     valid positions also having an available accuracy
--
-- Coordinates are included independently of accuracy.
--
-- Accuracy statistics are calculated only from records
-- having a valid coordinate pair and a positive accuracy.
--
-- Only bucket_5min is stored as temporal information.
-- =========================================================


CREATE TABLE IF NOT EXISTS gps_5min (

  userId   BIGINT       NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  firmware VARCHAR(128) NOT NULL,

  bucket_5min DATETIME NOT NULL,

  records_n      SMALLINT UNSIGNED NOT NULL,
  position_raw_n SMALLINT UNSIGNED NOT NULL,

  longitude_mean DOUBLE NULL,
  longitude_min  DOUBLE NULL,
  longitude_max  DOUBLE NULL,

  latitude_mean DOUBLE NULL,
  latitude_min  DOUBLE NULL,
  latitude_max  DOUBLE NULL,

  accuracy_mean  DOUBLE NULL,
  accuracy_min   DOUBLE NULL,
  accuracy_max   DOUBLE NULL,
  accuracy_raw_n SMALLINT UNSIGNED NOT NULL,

  PRIMARY KEY (
    deviceId,
    firmware,
    bucket_5min
  ),

  INDEX idx_gps_5min_user_bucket5 (
    userId,
    bucket_5min
  ),

  INDEX idx_gps_5min_bucket5 (
    bucket_5min
  )

) ENGINE=InnoDB;


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_gps_5min()
BEGIN

  -- Full rebuild of the materialized five-minute table
  DROP TABLE IF EXISTS gps_5min;

  CREATE TABLE gps_5min (

    userId   BIGINT       NOT NULL,
    deviceId VARCHAR(128) NOT NULL,
    firmware VARCHAR(128) NOT NULL,

    bucket_5min DATETIME NOT NULL,

    records_n      SMALLINT UNSIGNED NOT NULL,
    position_raw_n SMALLINT UNSIGNED NOT NULL,

    longitude_mean DOUBLE NULL,
    longitude_min  DOUBLE NULL,
    longitude_max  DOUBLE NULL,

    latitude_mean DOUBLE NULL,
    latitude_min  DOUBLE NULL,
    latitude_max  DOUBLE NULL,

    accuracy_mean  DOUBLE NULL,
    accuracy_min   DOUBLE NULL,
    accuracy_max   DOUBLE NULL,
    accuracy_raw_n SMALLINT UNSIGNED NOT NULL,

    PRIMARY KEY (
      deviceId,
      firmware,
      bucket_5min
    ),

    INDEX idx_gps_5min_user_bucket5 (
      userId,
      bucket_5min
    ),

    INDEX idx_gps_5min_bucket5 (
      bucket_5min
    )

  ) ENGINE=InnoDB;


  INSERT INTO gps_5min (
    userId,
    deviceId,
    firmware,
    bucket_5min,

    records_n,
    position_raw_n,

    longitude_mean,
    longitude_min,
    longitude_max,

    latitude_mean,
    latitude_min,
    latitude_max,

    accuracy_mean,
    accuracy_min,
    accuracy_max,
    accuracy_raw_n
  )

  SELECT
    userId,
    deviceId,
    firmware,
    bucket_5min,

    -- All tidy records in the bucket
    COUNT(*) AS records_n,

    -- In gps_tidy longitude and latitude are validated as
    -- a pair, so COUNT(longitude) counts valid positions.
    COUNT(longitude) AS position_raw_n,

    -- Coordinate summaries include all valid positions,
    -- regardless of accuracy availability.
    AVG(longitude) AS longitude_mean,
    MIN(longitude) AS longitude_min,
    MAX(longitude) AS longitude_max,

    AVG(latitude) AS latitude_mean,
    MIN(latitude) AS latitude_min,
    MAX(latitude) AS latitude_max,

    -- Accuracy is summarized only when the associated
    -- coordinate pair is valid.
    AVG(
      CASE
        WHEN longitude IS NOT NULL
         AND latitude  IS NOT NULL
        THEN accuracy
        ELSE NULL
      END
    ) AS accuracy_mean,

    MIN(
      CASE
        WHEN longitude IS NOT NULL
         AND latitude  IS NOT NULL
        THEN accuracy
        ELSE NULL
      END
    ) AS accuracy_min,

    MAX(
      CASE
        WHEN longitude IS NOT NULL
         AND latitude  IS NOT NULL
        THEN accuracy
        ELSE NULL
      END
    ) AS accuracy_max,

    COUNT(
      CASE
        WHEN longitude IS NOT NULL
         AND latitude  IS NOT NULL
         AND accuracy  IS NOT NULL
        THEN 1
        ELSE NULL
      END
    ) AS accuracy_raw_n

  FROM gps_tidy

  GROUP BY
    userId,
    deviceId,
    firmware,
    bucket_5min;

END//


DELIMITER ;
