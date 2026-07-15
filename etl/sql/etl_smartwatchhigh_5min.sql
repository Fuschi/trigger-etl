-- =========================================================
-- etl_smartwatchhigh_5min.sql
--
-- Materialized five-minute aggregation of
-- smartwatchhigh_tidy.
--
-- One row per device, firmware and fixed five-minute bucket.
--
-- Each bucket is represented by its starting timestamp:
--   10:00:00 <= event_ts < 10:05:00 -> 10:00:00
--   10:05:00 <= event_ts < 10:10:00 -> 10:05:00
--
-- Continuous measurements:
--   mean  : arithmetic mean of valid readings
--   min   : minimum valid reading
--   max   : maximum valid reading
--   raw_n : number of valid readings
--
-- sleeprate is categorical and is represented through
-- counts for each valid class rather than through a mean.
--
-- raw_n values describe sampling density and must not be
-- used as weights in hourly or daily temporal averages.
-- =========================================================


CREATE TABLE IF NOT EXISTS smartwatchhigh_5min (

  userId   BIGINT       NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  firmware VARCHAR(128) NOT NULL,

  bucket_5min DATETIME NOT NULL,
  date        DATE     NOT NULL,
  hour        TINYINT  NOT NULL,
  minute      TINYINT  NOT NULL,

  -- Total tidy records within the five-minute interval
  records_n SMALLINT UNSIGNED NOT NULL,

  heartrate_mean  DOUBLE NULL,
  heartrate_min   DOUBLE NULL,
  heartrate_max   DOUBLE NULL,
  heartrate_raw_n SMALLINT UNSIGNED NOT NULL,

  oxygens_mean  DOUBLE NULL,
  oxygens_min   DOUBLE NULL,
  oxygens_max   DOUBLE NULL,
  oxygens_raw_n SMALLINT UNSIGNED NOT NULL,

  breathrate_mean  DOUBLE NULL,
  breathrate_min   DOUBLE NULL,
  breathrate_max   DOUBLE NULL,
  breathrate_raw_n SMALLINT UNSIGNED NOT NULL,

  -- Sleep-stage counts
  sleeprate_raw_n SMALLINT UNSIGNED NOT NULL,
  sleeprate_1_n   SMALLINT UNSIGNED NOT NULL,
  sleeprate_2_n   SMALLINT UNSIGNED NOT NULL,
  sleeprate_3_n   SMALLINT UNSIGNED NOT NULL,
  sleeprate_4_n   SMALLINT UNSIGNED NOT NULL,

  PRIMARY KEY (
    deviceId,
    firmware,
    bucket_5min
  ),

  INDEX idx_smartwatchhigh_5min_user_bucket5 (
    userId,
    bucket_5min
  ),

  INDEX idx_smartwatchhigh_5min_bucket5 (
    bucket_5min
  ),

  INDEX idx_smartwatchhigh_5min_date (
    date
  )

) ENGINE=InnoDB;


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_smartwatchhigh_5min()
BEGIN

  -- Full rebuild of the materialized five-minute table
  DROP TABLE IF EXISTS smartwatchhigh_5min;

  CREATE TABLE smartwatchhigh_5min (

    userId   BIGINT       NOT NULL,
    deviceId VARCHAR(128) NOT NULL,
    firmware VARCHAR(128) NOT NULL,

    bucket_5min DATETIME NOT NULL,
    date        DATE     NOT NULL,
    hour        TINYINT  NOT NULL,
    minute      TINYINT  NOT NULL,

    records_n SMALLINT UNSIGNED NOT NULL,

    heartrate_mean  DOUBLE NULL,
    heartrate_min   DOUBLE NULL,
    heartrate_max   DOUBLE NULL,
    heartrate_raw_n SMALLINT UNSIGNED NOT NULL,

    oxygens_mean  DOUBLE NULL,
    oxygens_min   DOUBLE NULL,
    oxygens_max   DOUBLE NULL,
    oxygens_raw_n SMALLINT UNSIGNED NOT NULL,

    breathrate_mean  DOUBLE NULL,
    breathrate_min   DOUBLE NULL,
    breathrate_max   DOUBLE NULL,
    breathrate_raw_n SMALLINT UNSIGNED NOT NULL,

    sleeprate_raw_n SMALLINT UNSIGNED NOT NULL,
    sleeprate_1_n   SMALLINT UNSIGNED NOT NULL,
    sleeprate_2_n   SMALLINT UNSIGNED NOT NULL,
    sleeprate_3_n   SMALLINT UNSIGNED NOT NULL,
    sleeprate_4_n   SMALLINT UNSIGNED NOT NULL,

    PRIMARY KEY (
      deviceId,
      firmware,
      bucket_5min
    ),

    INDEX idx_smartwatchhigh_5min_user_bucket5 (
      userId,
      bucket_5min
    ),

    INDEX idx_smartwatchhigh_5min_bucket5 (
      bucket_5min
    ),

    INDEX idx_smartwatchhigh_5min_date (
      date
    )

  ) ENGINE=InnoDB;


  INSERT INTO smartwatchhigh_5min (
    userId,
    deviceId,
    firmware,

    bucket_5min,
    date,
    hour,
    minute,

    records_n,

    heartrate_mean,
    heartrate_min,
    heartrate_max,
    heartrate_raw_n,

    oxygens_mean,
    oxygens_min,
    oxygens_max,
    oxygens_raw_n,

    breathrate_mean,
    breathrate_min,
    breathrate_max,
    breathrate_raw_n,

    sleeprate_raw_n,
    sleeprate_1_n,
    sleeprate_2_n,
    sleeprate_3_n,
    sleeprate_4_n
  )

  SELECT
    userId,
    deviceId,
    firmware,

    bucket_5min,
    DATE(bucket_5min)   AS date,
    HOUR(bucket_5min)   AS hour,
    MINUTE(bucket_5min) AS minute,

    COUNT(*) AS records_n,

    AVG(heartrate)   AS heartrate_mean,
    MIN(heartrate)   AS heartrate_min,
    MAX(heartrate)   AS heartrate_max,
    COUNT(heartrate) AS heartrate_raw_n,

    AVG(oxygens)   AS oxygens_mean,
    MIN(oxygens)   AS oxygens_min,
    MAX(oxygens)   AS oxygens_max,
    COUNT(oxygens) AS oxygens_raw_n,

    AVG(breathrate)   AS breathrate_mean,
    MIN(breathrate)   AS breathrate_min,
    MAX(breathrate)   AS breathrate_max,
    COUNT(breathrate) AS breathrate_raw_n,

    COUNT(sleeprate) AS sleeprate_raw_n,

    SUM(
      CASE
        WHEN sleeprate = 1 THEN 1
        ELSE 0
      END
    ) AS sleeprate_1_n,

    SUM(
      CASE
        WHEN sleeprate = 2 THEN 1
        ELSE 0
      END
    ) AS sleeprate_2_n,

    SUM(
      CASE
        WHEN sleeprate = 3 THEN 1
        ELSE 0
      END
    ) AS sleeprate_3_n,

    SUM(
      CASE
        WHEN sleeprate = 4 THEN 1
        ELSE 0
      END
    ) AS sleeprate_4_n

  FROM smartwatchhigh_tidy

  GROUP BY
    userId,
    deviceId,
    firmware,
    bucket_5min;

END//


DELIMITER ;
