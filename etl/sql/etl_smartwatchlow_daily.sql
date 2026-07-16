-- =========================================================
-- etl_smartwatchlow_daily.sql
--
-- Materialized daily aggregation of smartwatchlow_5min.
--
-- One row per device, firmware and calendar date.
-- Daily means are calculated directly from five-minute
-- means so every observed interval receives equal temporal
-- weight.
--
-- The exact semantics of step and cal are intentionally not
-- assumed. The daily table therefore preserves:
--   mean, minimum, maximum, sum, first value, last value,
--   raw-reading count, five-minute coverage and hourly
--   coverage.
--
-- first and last are the earliest and latest available
-- five-minute values within the calendar date.
--
-- No minimum coverage threshold is applied here.
-- =========================================================


CREATE TABLE IF NOT EXISTS smartwatchlow_daily (

  userId   BIGINT       NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  firmware VARCHAR(128) NOT NULL,

  date DATE NOT NULL,

  records_n  SMALLINT UNSIGNED NOT NULL,
  five_min_n SMALLINT UNSIGNED NOT NULL,
  hours_n    TINYINT UNSIGNED  NOT NULL,

  step_mean    DOUBLE NULL,
  step_min     DOUBLE NULL,
  step_max     DOUBLE NULL,
  step_sum     DOUBLE NULL,
  step_first   DOUBLE NULL,
  step_last    DOUBLE NULL,
  step_raw_n   SMALLINT UNSIGNED NOT NULL,
  step_5min_n  SMALLINT UNSIGNED NOT NULL,
  step_hours_n TINYINT UNSIGNED NOT NULL,

  cal_mean    DOUBLE NULL,
  cal_min     DOUBLE NULL,
  cal_max     DOUBLE NULL,
  cal_sum     DOUBLE NULL,
  cal_first   DOUBLE NULL,
  cal_last    DOUBLE NULL,
  cal_raw_n   SMALLINT UNSIGNED NOT NULL,
  cal_5min_n  SMALLINT UNSIGNED NOT NULL,
  cal_hours_n TINYINT UNSIGNED NOT NULL,

  bphigh_mean    DOUBLE NULL,
  bphigh_min     DOUBLE NULL,
  bphigh_max     DOUBLE NULL,
  bphigh_raw_n   SMALLINT UNSIGNED NOT NULL,
  bphigh_5min_n  SMALLINT UNSIGNED NOT NULL,
  bphigh_hours_n TINYINT UNSIGNED NOT NULL,

  bplow_mean    DOUBLE NULL,
  bplow_min     DOUBLE NULL,
  bplow_max     DOUBLE NULL,
  bplow_raw_n   SMALLINT UNSIGNED NOT NULL,
  bplow_5min_n  SMALLINT UNSIGNED NOT NULL,
  bplow_hours_n TINYINT UNSIGNED NOT NULL,

  bodytemp_mean    DOUBLE NULL,
  bodytemp_min     DOUBLE NULL,
  bodytemp_max     DOUBLE NULL,
  bodytemp_raw_n   SMALLINT UNSIGNED NOT NULL,
  bodytemp_5min_n  SMALLINT UNSIGNED NOT NULL,
  bodytemp_hours_n TINYINT UNSIGNED NOT NULL,

  skintemp_mean    DOUBLE NULL,
  skintemp_min     DOUBLE NULL,
  skintemp_max     DOUBLE NULL,
  skintemp_raw_n   SMALLINT UNSIGNED NOT NULL,
  skintemp_5min_n  SMALLINT UNSIGNED NOT NULL,
  skintemp_hours_n TINYINT UNSIGNED NOT NULL,

  PRIMARY KEY (
    deviceId,
    firmware,
    date
  ),

  INDEX idx_smartwatchlow_daily_user_date (
    userId,
    date
  ),

  INDEX idx_smartwatchlow_daily_date (
    date
  )

) ENGINE=InnoDB;


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_smartwatchlow_daily()
BEGIN

  -- Full rebuild of the materialized daily table
  DROP TABLE IF EXISTS smartwatchlow_daily;

  CREATE TABLE smartwatchlow_daily (

    userId   BIGINT       NOT NULL,
    deviceId VARCHAR(128) NOT NULL,
    firmware VARCHAR(128) NOT NULL,

    date DATE NOT NULL,

    records_n  SMALLINT UNSIGNED NOT NULL,
    five_min_n SMALLINT UNSIGNED NOT NULL,
    hours_n    TINYINT UNSIGNED  NOT NULL,

    step_mean    DOUBLE NULL,
    step_min     DOUBLE NULL,
    step_max     DOUBLE NULL,
    step_sum     DOUBLE NULL,
    step_first   DOUBLE NULL,
    step_last    DOUBLE NULL,
    step_raw_n   SMALLINT UNSIGNED NOT NULL,
    step_5min_n  SMALLINT UNSIGNED NOT NULL,
    step_hours_n TINYINT UNSIGNED NOT NULL,

    cal_mean    DOUBLE NULL,
    cal_min     DOUBLE NULL,
    cal_max     DOUBLE NULL,
    cal_sum     DOUBLE NULL,
    cal_first   DOUBLE NULL,
    cal_last    DOUBLE NULL,
    cal_raw_n   SMALLINT UNSIGNED NOT NULL,
    cal_5min_n  SMALLINT UNSIGNED NOT NULL,
    cal_hours_n TINYINT UNSIGNED NOT NULL,

    bphigh_mean    DOUBLE NULL,
    bphigh_min     DOUBLE NULL,
    bphigh_max     DOUBLE NULL,
    bphigh_raw_n   SMALLINT UNSIGNED NOT NULL,
    bphigh_5min_n  SMALLINT UNSIGNED NOT NULL,
    bphigh_hours_n TINYINT UNSIGNED NOT NULL,

    bplow_mean    DOUBLE NULL,
    bplow_min     DOUBLE NULL,
    bplow_max     DOUBLE NULL,
    bplow_raw_n   SMALLINT UNSIGNED NOT NULL,
    bplow_5min_n  SMALLINT UNSIGNED NOT NULL,
    bplow_hours_n TINYINT UNSIGNED NOT NULL,

    bodytemp_mean    DOUBLE NULL,
    bodytemp_min     DOUBLE NULL,
    bodytemp_max     DOUBLE NULL,
    bodytemp_raw_n   SMALLINT UNSIGNED NOT NULL,
    bodytemp_5min_n  SMALLINT UNSIGNED NOT NULL,
    bodytemp_hours_n TINYINT UNSIGNED NOT NULL,

    skintemp_mean    DOUBLE NULL,
    skintemp_min     DOUBLE NULL,
    skintemp_max     DOUBLE NULL,
    skintemp_raw_n   SMALLINT UNSIGNED NOT NULL,
    skintemp_5min_n  SMALLINT UNSIGNED NOT NULL,
    skintemp_hours_n TINYINT UNSIGNED NOT NULL,

    PRIMARY KEY (
      deviceId,
      firmware,
      date
    ),

    INDEX idx_smartwatchlow_daily_user_date (
      userId,
      date
    ),

    INDEX idx_smartwatchlow_daily_date (
      date
    )

  ) ENGINE=InnoDB;


  INSERT INTO smartwatchlow_daily (
    userId,
    deviceId,
    firmware,
    date,

    records_n,
    five_min_n,
    hours_n,

    step_mean,
    step_min,
    step_max,
    step_sum,
    step_first,
    step_last,
    step_raw_n,
    step_5min_n,
    step_hours_n,

    cal_mean,
    cal_min,
    cal_max,
    cal_sum,
    cal_first,
    cal_last,
    cal_raw_n,
    cal_5min_n,
    cal_hours_n,

    bphigh_mean,
    bphigh_min,
    bphigh_max,
    bphigh_raw_n,
    bphigh_5min_n,
    bphigh_hours_n,

    bplow_mean,
    bplow_min,
    bplow_max,
    bplow_raw_n,
    bplow_5min_n,
    bplow_hours_n,

    bodytemp_mean,
    bodytemp_min,
    bodytemp_max,
    bodytemp_raw_n,
    bodytemp_5min_n,
    bodytemp_hours_n,

    skintemp_mean,
    skintemp_min,
    skintemp_max,
    skintemp_raw_n,
    skintemp_5min_n,
    skintemp_hours_n
  )

  WITH ordered AS (
    SELECT
      f.*,

      FIRST_VALUE(f.step_first) OVER (
        PARTITION BY
          f.userId,
          f.deviceId,
          f.firmware,
          f.date

        ORDER BY
          (f.step_first IS NULL),
          f.bucket_5min

        ROWS BETWEEN UNBOUNDED PRECEDING
                 AND UNBOUNDED FOLLOWING
      ) AS step_first_day,

      FIRST_VALUE(f.step_last) OVER (
        PARTITION BY
          f.userId,
          f.deviceId,
          f.firmware,
          f.date

        ORDER BY
          (f.step_last IS NULL),
          f.bucket_5min DESC

        ROWS BETWEEN UNBOUNDED PRECEDING
                 AND UNBOUNDED FOLLOWING
      ) AS step_last_day,

      FIRST_VALUE(f.cal_first) OVER (
        PARTITION BY
          f.userId,
          f.deviceId,
          f.firmware,
          f.date

        ORDER BY
          (f.cal_first IS NULL),
          f.bucket_5min

        ROWS BETWEEN UNBOUNDED PRECEDING
                 AND UNBOUNDED FOLLOWING
      ) AS cal_first_day,

      FIRST_VALUE(f.cal_last) OVER (
        PARTITION BY
          f.userId,
          f.deviceId,
          f.firmware,
          f.date

        ORDER BY
          (f.cal_last IS NULL),
          f.bucket_5min DESC

        ROWS BETWEEN UNBOUNDED PRECEDING
                 AND UNBOUNDED FOLLOWING
      ) AS cal_last_day

    FROM smartwatchlow_5min AS f
  )

  SELECT
    userId,
    deviceId,
    firmware,
    date,

    SUM(records_n) AS records_n,
    COUNT(*) AS five_min_n,
    COUNT(DISTINCT hour) AS hours_n,

    AVG(step_mean) AS step_mean,
    MIN(step_min) AS step_min,
    MAX(step_max) AS step_max,
    SUM(step_sum) AS step_sum,
    MAX(step_first_day) AS step_first,
    MAX(step_last_day) AS step_last,
    SUM(step_raw_n) AS step_raw_n,
    COUNT(step_mean) AS step_5min_n,
    COUNT(DISTINCT CASE,
      WHEN step_mean IS NOT NULL THEN hour,
      ELSE NULL,
    END) AS step_hours_n,

    AVG(cal_mean) AS cal_mean,
    MIN(cal_min) AS cal_min,
    MAX(cal_max) AS cal_max,
    SUM(cal_sum) AS cal_sum,
    MAX(cal_first_day) AS cal_first,
    MAX(cal_last_day) AS cal_last,
    SUM(cal_raw_n) AS cal_raw_n,
    COUNT(cal_mean) AS cal_5min_n,
    COUNT(DISTINCT CASE,
      WHEN cal_mean IS NOT NULL THEN hour,
      ELSE NULL,
    END) AS cal_hours_n,

    AVG(bphigh_mean) AS bphigh_mean,
    MIN(bphigh_min) AS bphigh_min,
    MAX(bphigh_max) AS bphigh_max,
    SUM(bphigh_raw_n) AS bphigh_raw_n,
    COUNT(bphigh_mean) AS bphigh_5min_n,
    COUNT(DISTINCT CASE,
      WHEN bphigh_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS bphigh_hours_n,

    AVG(bplow_mean) AS bplow_mean,
    MIN(bplow_min) AS bplow_min,
    MAX(bplow_max) AS bplow_max,
    SUM(bplow_raw_n) AS bplow_raw_n,
    COUNT(bplow_mean) AS bplow_5min_n,
    COUNT(DISTINCT CASE,
      WHEN bplow_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS bplow_hours_n,

    AVG(bodytemp_mean) AS bodytemp_mean,
    MIN(bodytemp_min) AS bodytemp_min,
    MAX(bodytemp_max) AS bodytemp_max,
    SUM(bodytemp_raw_n) AS bodytemp_raw_n,
    COUNT(bodytemp_mean) AS bodytemp_5min_n,
    COUNT(DISTINCT CASE,
      WHEN bodytemp_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS bodytemp_hours_n,

    AVG(skintemp_mean) AS skintemp_mean,
    MIN(skintemp_min) AS skintemp_min,
    MAX(skintemp_max) AS skintemp_max,
    SUM(skintemp_raw_n) AS skintemp_raw_n,
    COUNT(skintemp_mean) AS skintemp_5min_n,
    COUNT(DISTINCT CASE,
      WHEN skintemp_mean IS NOT NULL,
      THEN HOUR(bucket_5min),
      ELSE NULL,
    END) AS skintemp_hours_n

  FROM ordered

  GROUP BY
    userId,
    deviceId,
    firmware,
    date;

END//


DELIMITER ;
