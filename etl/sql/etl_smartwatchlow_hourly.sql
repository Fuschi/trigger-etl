-- =========================================================
-- etl_smartwatchlow_hourly.sql
--
-- Materialized hourly aggregation of smartwatchlow_5min.
--
-- One row per device, firmware and fixed hourly bucket.
-- Each available five-minute interval receives equal
-- temporal weight in hourly means.
--
-- The exact semantics of step and cal are still retained
-- without assuming whether they are increments or cumulative
-- counters. Hourly output therefore preserves mean, minimum,
-- maximum, sum, first value, last value and observation counts.
--
-- first and last refer to the earliest and latest available
-- five-minute values within the hour.
-- =========================================================


CREATE TABLE IF NOT EXISTS smartwatchlow_hourly (

  userId   BIGINT       NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  firmware VARCHAR(128) NOT NULL,

  bucket_hour DATETIME NOT NULL,

  records_n  SMALLINT UNSIGNED NOT NULL,
  five_min_n TINYINT UNSIGNED  NOT NULL,

  step_mean   DOUBLE NULL,
  step_min    DOUBLE NULL,
  step_max    DOUBLE NULL,
  step_sum    DOUBLE NULL,
  step_first  DOUBLE NULL,
  step_last   DOUBLE NULL,
  step_raw_n  SMALLINT UNSIGNED NOT NULL,
  step_5min_n TINYINT UNSIGNED NOT NULL,

  cal_mean   DOUBLE NULL,
  cal_min    DOUBLE NULL,
  cal_max    DOUBLE NULL,
  cal_sum    DOUBLE NULL,
  cal_first  DOUBLE NULL,
  cal_last   DOUBLE NULL,
  cal_raw_n  SMALLINT UNSIGNED NOT NULL,
  cal_5min_n TINYINT UNSIGNED NOT NULL,

  bphigh_mean   DOUBLE NULL,
  bphigh_min    DOUBLE NULL,
  bphigh_max    DOUBLE NULL,
  bphigh_raw_n  SMALLINT UNSIGNED NOT NULL,
  bphigh_5min_n TINYINT UNSIGNED NOT NULL,

  bplow_mean   DOUBLE NULL,
  bplow_min    DOUBLE NULL,
  bplow_max    DOUBLE NULL,
  bplow_raw_n  SMALLINT UNSIGNED NOT NULL,
  bplow_5min_n TINYINT UNSIGNED NOT NULL,

  bodytemp_mean   DOUBLE NULL,
  bodytemp_min    DOUBLE NULL,
  bodytemp_max    DOUBLE NULL,
  bodytemp_raw_n  SMALLINT UNSIGNED NOT NULL,
  bodytemp_5min_n TINYINT UNSIGNED NOT NULL,

  skintemp_mean   DOUBLE NULL,
  skintemp_min    DOUBLE NULL,
  skintemp_max    DOUBLE NULL,
  skintemp_raw_n  SMALLINT UNSIGNED NOT NULL,
  skintemp_5min_n TINYINT UNSIGNED NOT NULL,

  PRIMARY KEY (
    deviceId,
    firmware,
    bucket_hour
  ),

  INDEX idx_smartwatchlow_hourly_user_bucket (
    userId,
    bucket_hour
  ),

  INDEX idx_smartwatchlow_hourly_bucket (
    bucket_hour
  )

) ENGINE=InnoDB;


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_smartwatchlow_hourly()
BEGIN

  DROP TABLE IF EXISTS smartwatchlow_hourly;

  CREATE TABLE smartwatchlow_hourly (

    userId   BIGINT       NOT NULL,
    deviceId VARCHAR(128) NOT NULL,
    firmware VARCHAR(128) NOT NULL,

    bucket_hour DATETIME NOT NULL,

    records_n  SMALLINT UNSIGNED NOT NULL,
    five_min_n TINYINT UNSIGNED  NOT NULL,

    step_mean   DOUBLE NULL,
    step_min    DOUBLE NULL,
    step_max    DOUBLE NULL,
    step_sum    DOUBLE NULL,
    step_first  DOUBLE NULL,
    step_last   DOUBLE NULL,
    step_raw_n  SMALLINT UNSIGNED NOT NULL,
    step_5min_n TINYINT UNSIGNED NOT NULL,

    cal_mean   DOUBLE NULL,
    cal_min    DOUBLE NULL,
    cal_max    DOUBLE NULL,
    cal_sum    DOUBLE NULL,
    cal_first  DOUBLE NULL,
    cal_last   DOUBLE NULL,
    cal_raw_n  SMALLINT UNSIGNED NOT NULL,
    cal_5min_n TINYINT UNSIGNED NOT NULL,

    bphigh_mean   DOUBLE NULL,
    bphigh_min    DOUBLE NULL,
    bphigh_max    DOUBLE NULL,
    bphigh_raw_n  SMALLINT UNSIGNED NOT NULL,
    bphigh_5min_n TINYINT UNSIGNED NOT NULL,

    bplow_mean   DOUBLE NULL,
    bplow_min    DOUBLE NULL,
    bplow_max    DOUBLE NULL,
    bplow_raw_n  SMALLINT UNSIGNED NOT NULL,
    bplow_5min_n TINYINT UNSIGNED NOT NULL,

    bodytemp_mean   DOUBLE NULL,
    bodytemp_min    DOUBLE NULL,
    bodytemp_max    DOUBLE NULL,
    bodytemp_raw_n  SMALLINT UNSIGNED NOT NULL,
    bodytemp_5min_n TINYINT UNSIGNED NOT NULL,

    skintemp_mean   DOUBLE NULL,
    skintemp_min    DOUBLE NULL,
    skintemp_max    DOUBLE NULL,
    skintemp_raw_n  SMALLINT UNSIGNED NOT NULL,
    skintemp_5min_n TINYINT UNSIGNED NOT NULL,

    PRIMARY KEY (
      deviceId,
      firmware,
      bucket_hour
    ),

    INDEX idx_smartwatchlow_hourly_user_bucket (
      userId,
      bucket_hour
    ),

    INDEX idx_smartwatchlow_hourly_bucket (
      bucket_hour
    )

  ) ENGINE=InnoDB;


  INSERT INTO smartwatchlow_hourly (
    userId,
    deviceId,
    firmware,
    bucket_hour,

    records_n,
    five_min_n,

    step_mean,
    step_min,
    step_max,
    step_sum,
    step_first,
    step_last,
    step_raw_n,
    step_5min_n,

    cal_mean,
    cal_min,
    cal_max,
    cal_sum,
    cal_first,
    cal_last,
    cal_raw_n,
    cal_5min_n,

    bphigh_mean,
    bphigh_min,
    bphigh_max,
    bphigh_raw_n,
    bphigh_5min_n,

    bplow_mean,
    bplow_min,
    bplow_max,
    bplow_raw_n,
    bplow_5min_n,

    bodytemp_mean,
    bodytemp_min,
    bodytemp_max,
    bodytemp_raw_n,
    bodytemp_5min_n,

    skintemp_mean,
    skintemp_min,
    skintemp_max,
    skintemp_raw_n,
    skintemp_5min_n
  )

  WITH bucketed AS (
    SELECT
      f.*,

      TIMESTAMP(
        DATE(f.bucket_5min),
        MAKETIME(HOUR(f.bucket_5min), 0, 0)
      ) AS bucket_hour

    FROM smartwatchlow_5min AS f
  ),

  ordered AS (
    SELECT
      b.*,

      FIRST_VALUE(b.step_first) OVER (
        PARTITION BY
          b.userId,
          b.deviceId,
          b.firmware,
          b.bucket_hour

        ORDER BY
          CASE WHEN b.step_first IS NULL THEN 1 ELSE 0 END,
          b.bucket_5min
      ) AS step_first_hour,

      FIRST_VALUE(b.step_last) OVER (
        PARTITION BY
          b.userId,
          b.deviceId,
          b.firmware,
          b.bucket_hour

        ORDER BY
          CASE WHEN b.step_last IS NULL THEN 1 ELSE 0 END,
          b.bucket_5min DESC
      ) AS step_last_hour,

      FIRST_VALUE(b.cal_first) OVER (
        PARTITION BY
          b.userId,
          b.deviceId,
          b.firmware,
          b.bucket_hour

        ORDER BY
          CASE WHEN b.cal_first IS NULL THEN 1 ELSE 0 END,
          b.bucket_5min
      ) AS cal_first_hour,

      FIRST_VALUE(b.cal_last) OVER (
        PARTITION BY
          b.userId,
          b.deviceId,
          b.firmware,
          b.bucket_hour

        ORDER BY
          CASE WHEN b.cal_last IS NULL THEN 1 ELSE 0 END,
          b.bucket_5min DESC
      ) AS cal_last_hour

    FROM bucketed AS b
  )

  SELECT
    userId,
    deviceId,
    firmware,
    bucket_hour,

    SUM(records_n) AS records_n,
    COUNT(*)       AS five_min_n,

    AVG(step_mean)        AS step_mean,
    MIN(step_min)         AS step_min,
    MAX(step_max)         AS step_max,
    SUM(step_sum)         AS step_sum,
    MAX(step_first_hour)  AS step_first,
    MAX(step_last_hour)   AS step_last,
    SUM(step_raw_n)       AS step_raw_n,
    COUNT(step_mean)      AS step_5min_n,

    AVG(cal_mean)       AS cal_mean,
    MIN(cal_min)        AS cal_min,
    MAX(cal_max)        AS cal_max,
    SUM(cal_sum)        AS cal_sum,
    MAX(cal_first_hour) AS cal_first,
    MAX(cal_last_hour)  AS cal_last,
    SUM(cal_raw_n)      AS cal_raw_n,
    COUNT(cal_mean)     AS cal_5min_n,

    AVG(bphigh_mean)   AS bphigh_mean,
    MIN(bphigh_min)    AS bphigh_min,
    MAX(bphigh_max)    AS bphigh_max,
    SUM(bphigh_raw_n)  AS bphigh_raw_n,
    COUNT(bphigh_mean) AS bphigh_5min_n,

    AVG(bplow_mean)   AS bplow_mean,
    MIN(bplow_min)    AS bplow_min,
    MAX(bplow_max)    AS bplow_max,
    SUM(bplow_raw_n)  AS bplow_raw_n,
    COUNT(bplow_mean) AS bplow_5min_n,

    AVG(bodytemp_mean)   AS bodytemp_mean,
    MIN(bodytemp_min)    AS bodytemp_min,
    MAX(bodytemp_max)    AS bodytemp_max,
    SUM(bodytemp_raw_n)  AS bodytemp_raw_n,
    COUNT(bodytemp_mean) AS bodytemp_5min_n,

    AVG(skintemp_mean)   AS skintemp_mean,
    MIN(skintemp_min)    AS skintemp_min,
    MAX(skintemp_max)    AS skintemp_max,
    SUM(skintemp_raw_n)  AS skintemp_raw_n,
    COUNT(skintemp_mean) AS skintemp_5min_n

  FROM ordered

  GROUP BY
    userId,
    deviceId,
    firmware,
    bucket_hour;

END//


DELIMITER ;
