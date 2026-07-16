-- =========================================================
-- etl_smartwatchlow_daily.sql
--
-- Materialized daily aggregation of smartwatchlow_hourly.
--
-- One row per device, firmware and calendar date.
-- Daily means are unweighted means of available hourly means.
--
-- Each measurement has a fixed JSON profile of 24 values,
-- ordered from hour 00 to hour 23. Each value reports the
-- number of valid five-minute buckets represented in that
-- hour, from 0 to 12.
--
-- step and cal retain mean, minimum, maximum, sum, first and
-- last values because their cumulative/increment semantics
-- have not yet been fixed.
--
-- No coverage threshold is enforced in the ETL.
-- =========================================================


CREATE TABLE IF NOT EXISTS smartwatchlow_daily (

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

  step_mean                    DOUBLE NULL,
  step_min                     DOUBLE NULL,
  step_max                     DOUBLE NULL,
  step_sum                     DOUBLE NULL,
  step_first                   DOUBLE NULL,
  step_last                    DOUBLE NULL,
  step_raw_n                   INT UNSIGNED NOT NULL,
  step_hours_n                 TINYINT UNSIGNED NOT NULL,
  step_5min_n                  SMALLINT UNSIGNED NOT NULL,
  step_5min_per_hour_mean      DOUBLE NULL,
  step_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  step_5min_profile            JSON NOT NULL,

  cal_mean                    DOUBLE NULL,
  cal_min                     DOUBLE NULL,
  cal_max                     DOUBLE NULL,
  cal_sum                     DOUBLE NULL,
  cal_first                   DOUBLE NULL,
  cal_last                    DOUBLE NULL,
  cal_raw_n                   INT UNSIGNED NOT NULL,
  cal_hours_n                 TINYINT UNSIGNED NOT NULL,
  cal_5min_n                  SMALLINT UNSIGNED NOT NULL,
  cal_5min_per_hour_mean      DOUBLE NULL,
  cal_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  cal_5min_profile            JSON NOT NULL,

  bphigh_mean                    DOUBLE NULL,
  bphigh_min                     DOUBLE NULL,
  bphigh_max                     DOUBLE NULL,
  bphigh_raw_n                   INT UNSIGNED NOT NULL,
  bphigh_hours_n                 TINYINT UNSIGNED NOT NULL,
  bphigh_5min_n                  SMALLINT UNSIGNED NOT NULL,
  bphigh_5min_per_hour_mean      DOUBLE NULL,
  bphigh_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  bphigh_5min_profile            JSON NOT NULL,

  bplow_mean                    DOUBLE NULL,
  bplow_min                     DOUBLE NULL,
  bplow_max                     DOUBLE NULL,
  bplow_raw_n                   INT UNSIGNED NOT NULL,
  bplow_hours_n                 TINYINT UNSIGNED NOT NULL,
  bplow_5min_n                  SMALLINT UNSIGNED NOT NULL,
  bplow_5min_per_hour_mean      DOUBLE NULL,
  bplow_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  bplow_5min_profile            JSON NOT NULL,

  bodytemp_mean                    DOUBLE NULL,
  bodytemp_min                     DOUBLE NULL,
  bodytemp_max                     DOUBLE NULL,
  bodytemp_raw_n                   INT UNSIGNED NOT NULL,
  bodytemp_hours_n                 TINYINT UNSIGNED NOT NULL,
  bodytemp_5min_n                  SMALLINT UNSIGNED NOT NULL,
  bodytemp_5min_per_hour_mean      DOUBLE NULL,
  bodytemp_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  bodytemp_5min_profile            JSON NOT NULL,

  skintemp_mean                    DOUBLE NULL,
  skintemp_min                     DOUBLE NULL,
  skintemp_max                     DOUBLE NULL,
  skintemp_raw_n                   INT UNSIGNED NOT NULL,
  skintemp_hours_n                 TINYINT UNSIGNED NOT NULL,
  skintemp_5min_n                  SMALLINT UNSIGNED NOT NULL,
  skintemp_5min_per_hour_mean      DOUBLE NULL,
  skintemp_complete_hours_n        TINYINT UNSIGNED NOT NULL,
  skintemp_5min_profile            JSON NOT NULL,

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

  DROP TABLE IF EXISTS smartwatchlow_daily;

  CREATE TABLE smartwatchlow_daily (

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

    step_mean                    DOUBLE NULL,
    step_min                     DOUBLE NULL,
    step_max                     DOUBLE NULL,
    step_sum                     DOUBLE NULL,
    step_first                   DOUBLE NULL,
    step_last                    DOUBLE NULL,
    step_raw_n                   INT UNSIGNED NOT NULL,
    step_hours_n                 TINYINT UNSIGNED NOT NULL,
    step_5min_n                  SMALLINT UNSIGNED NOT NULL,
    step_5min_per_hour_mean      DOUBLE NULL,
    step_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    step_5min_profile            JSON NOT NULL,

    cal_mean                    DOUBLE NULL,
    cal_min                     DOUBLE NULL,
    cal_max                     DOUBLE NULL,
    cal_sum                     DOUBLE NULL,
    cal_first                   DOUBLE NULL,
    cal_last                    DOUBLE NULL,
    cal_raw_n                   INT UNSIGNED NOT NULL,
    cal_hours_n                 TINYINT UNSIGNED NOT NULL,
    cal_5min_n                  SMALLINT UNSIGNED NOT NULL,
    cal_5min_per_hour_mean      DOUBLE NULL,
    cal_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    cal_5min_profile            JSON NOT NULL,

    bphigh_mean                    DOUBLE NULL,
    bphigh_min                     DOUBLE NULL,
    bphigh_max                     DOUBLE NULL,
    bphigh_raw_n                   INT UNSIGNED NOT NULL,
    bphigh_hours_n                 TINYINT UNSIGNED NOT NULL,
    bphigh_5min_n                  SMALLINT UNSIGNED NOT NULL,
    bphigh_5min_per_hour_mean      DOUBLE NULL,
    bphigh_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    bphigh_5min_profile            JSON NOT NULL,

    bplow_mean                    DOUBLE NULL,
    bplow_min                     DOUBLE NULL,
    bplow_max                     DOUBLE NULL,
    bplow_raw_n                   INT UNSIGNED NOT NULL,
    bplow_hours_n                 TINYINT UNSIGNED NOT NULL,
    bplow_5min_n                  SMALLINT UNSIGNED NOT NULL,
    bplow_5min_per_hour_mean      DOUBLE NULL,
    bplow_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    bplow_5min_profile            JSON NOT NULL,

    bodytemp_mean                    DOUBLE NULL,
    bodytemp_min                     DOUBLE NULL,
    bodytemp_max                     DOUBLE NULL,
    bodytemp_raw_n                   INT UNSIGNED NOT NULL,
    bodytemp_hours_n                 TINYINT UNSIGNED NOT NULL,
    bodytemp_5min_n                  SMALLINT UNSIGNED NOT NULL,
    bodytemp_5min_per_hour_mean      DOUBLE NULL,
    bodytemp_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    bodytemp_5min_profile            JSON NOT NULL,

    skintemp_mean                    DOUBLE NULL,
    skintemp_min                     DOUBLE NULL,
    skintemp_max                     DOUBLE NULL,
    skintemp_raw_n                   INT UNSIGNED NOT NULL,
    skintemp_hours_n                 TINYINT UNSIGNED NOT NULL,
    skintemp_5min_n                  SMALLINT UNSIGNED NOT NULL,
    skintemp_5min_per_hour_mean      DOUBLE NULL,
    skintemp_complete_hours_n        TINYINT UNSIGNED NOT NULL,
    skintemp_5min_profile            JSON NOT NULL,

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
    hours_n,
    five_min_n,
    five_min_per_hour_mean,
    complete_hours_n,
    five_min_profile,

    step_mean,
    step_min,
    step_max,
    step_sum,
    step_first,
    step_last,
    step_raw_n,
    step_hours_n,
    step_5min_n,
    step_5min_per_hour_mean,
    step_complete_hours_n,
    step_5min_profile,

    cal_mean,
    cal_min,
    cal_max,
    cal_sum,
    cal_first,
    cal_last,
    cal_raw_n,
    cal_hours_n,
    cal_5min_n,
    cal_5min_per_hour_mean,
    cal_complete_hours_n,
    cal_5min_profile,

    bphigh_mean,
    bphigh_min,
    bphigh_max,
    bphigh_raw_n,
    bphigh_hours_n,
    bphigh_5min_n,
    bphigh_5min_per_hour_mean,
    bphigh_complete_hours_n,
    bphigh_5min_profile,

    bplow_mean,
    bplow_min,
    bplow_max,
    bplow_raw_n,
    bplow_hours_n,
    bplow_5min_n,
    bplow_5min_per_hour_mean,
    bplow_complete_hours_n,
    bplow_5min_profile,

    bodytemp_mean,
    bodytemp_min,
    bodytemp_max,
    bodytemp_raw_n,
    bodytemp_hours_n,
    bodytemp_5min_n,
    bodytemp_5min_per_hour_mean,
    bodytemp_complete_hours_n,
    bodytemp_5min_profile,

    skintemp_mean,
    skintemp_min,
    skintemp_max,
    skintemp_raw_n,
    skintemp_hours_n,
    skintemp_5min_n,
    skintemp_5min_per_hour_mean,
    skintemp_complete_hours_n,
    skintemp_5min_profile
  )

  WITH ranked AS (
    SELECT
      h.*,
      DATE(h.bucket_hour) AS date,

      ROW_NUMBER() OVER (
        PARTITION BY
          h.userId,
          h.deviceId,
          h.firmware,
          DATE(h.bucket_hour)
        ORDER BY
          CASE WHEN h.step_first IS NULL THEN 1 ELSE 0 END,
          h.bucket_hour
      ) AS step_first_rank,

      ROW_NUMBER() OVER (
        PARTITION BY
          h.userId,
          h.deviceId,
          h.firmware,
          DATE(h.bucket_hour)
        ORDER BY
          CASE WHEN h.step_last IS NULL THEN 1 ELSE 0 END,
          h.bucket_hour DESC
      ) AS step_last_rank,

      ROW_NUMBER() OVER (
        PARTITION BY
          h.userId,
          h.deviceId,
          h.firmware,
          DATE(h.bucket_hour)
        ORDER BY
          CASE WHEN h.cal_first IS NULL THEN 1 ELSE 0 END,
          h.bucket_hour
      ) AS cal_first_rank,

      ROW_NUMBER() OVER (
        PARTITION BY
          h.userId,
          h.deviceId,
          h.firmware,
          DATE(h.bucket_hour)
        ORDER BY
          CASE WHEN h.cal_last IS NULL THEN 1 ELSE 0 END,
          h.bucket_hour DESC
      ) AS cal_last_rank

    FROM smartwatchlow_hourly AS h
  )

  SELECT
    userId,
    deviceId,
    firmware,
    date,

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

    AVG(step_mean) AS step_mean,
    MIN(step_min) AS step_min,
    MAX(step_max) AS step_max,
    SUM(step_sum) AS step_sum,
    MAX(CASE WHEN step_first_rank = 1 THEN step_first ELSE NULL END) AS step_first,
    MAX(CASE WHEN step_last_rank = 1 THEN step_last ELSE NULL END) AS step_last,
    SUM(step_raw_n) AS step_raw_n,
    COUNT(step_mean) AS step_hours_n,
    SUM(step_5min_n) AS step_5min_n,
    AVG(CASE WHEN step_mean IS NOT NULL THEN step_5min_n ELSE NULL END) AS step_5min_per_hour_mean,
    SUM(CASE WHEN step_mean IS NOT NULL AND step_5min_n = 12 THEN 1 ELSE 0 END) AS step_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND step_mean IS NOT NULL
      THEN step_5min_n
      ELSE NULL
    END), 0)
  ) AS step_5min_profile,

    AVG(cal_mean) AS cal_mean,
    MIN(cal_min) AS cal_min,
    MAX(cal_max) AS cal_max,
    SUM(cal_sum) AS cal_sum,
    MAX(CASE WHEN cal_first_rank = 1 THEN cal_first ELSE NULL END) AS cal_first,
    MAX(CASE WHEN cal_last_rank = 1 THEN cal_last ELSE NULL END) AS cal_last,
    SUM(cal_raw_n) AS cal_raw_n,
    COUNT(cal_mean) AS cal_hours_n,
    SUM(cal_5min_n) AS cal_5min_n,
    AVG(CASE WHEN cal_mean IS NOT NULL THEN cal_5min_n ELSE NULL END) AS cal_5min_per_hour_mean,
    SUM(CASE WHEN cal_mean IS NOT NULL AND cal_5min_n = 12 THEN 1 ELSE 0 END) AS cal_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND cal_mean IS NOT NULL
      THEN cal_5min_n
      ELSE NULL
    END), 0)
  ) AS cal_5min_profile,

    AVG(bphigh_mean) AS bphigh_mean,
    MIN(bphigh_min) AS bphigh_min,
    MAX(bphigh_max) AS bphigh_max,
    SUM(bphigh_raw_n) AS bphigh_raw_n,
    COUNT(bphigh_mean) AS bphigh_hours_n,
    SUM(bphigh_5min_n) AS bphigh_5min_n,
    AVG(CASE WHEN bphigh_mean IS NOT NULL THEN bphigh_5min_n ELSE NULL END) AS bphigh_5min_per_hour_mean,
    SUM(CASE WHEN bphigh_mean IS NOT NULL AND bphigh_5min_n = 12 THEN 1 ELSE 0 END) AS bphigh_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND bphigh_mean IS NOT NULL
      THEN bphigh_5min_n
      ELSE NULL
    END), 0)
  ) AS bphigh_5min_profile,

    AVG(bplow_mean) AS bplow_mean,
    MIN(bplow_min) AS bplow_min,
    MAX(bplow_max) AS bplow_max,
    SUM(bplow_raw_n) AS bplow_raw_n,
    COUNT(bplow_mean) AS bplow_hours_n,
    SUM(bplow_5min_n) AS bplow_5min_n,
    AVG(CASE WHEN bplow_mean IS NOT NULL THEN bplow_5min_n ELSE NULL END) AS bplow_5min_per_hour_mean,
    SUM(CASE WHEN bplow_mean IS NOT NULL AND bplow_5min_n = 12 THEN 1 ELSE 0 END) AS bplow_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND bplow_mean IS NOT NULL
      THEN bplow_5min_n
      ELSE NULL
    END), 0)
  ) AS bplow_5min_profile,

    AVG(bodytemp_mean) AS bodytemp_mean,
    MIN(bodytemp_min) AS bodytemp_min,
    MAX(bodytemp_max) AS bodytemp_max,
    SUM(bodytemp_raw_n) AS bodytemp_raw_n,
    COUNT(bodytemp_mean) AS bodytemp_hours_n,
    SUM(bodytemp_5min_n) AS bodytemp_5min_n,
    AVG(CASE WHEN bodytemp_mean IS NOT NULL THEN bodytemp_5min_n ELSE NULL END) AS bodytemp_5min_per_hour_mean,
    SUM(CASE WHEN bodytemp_mean IS NOT NULL AND bodytemp_5min_n = 12 THEN 1 ELSE 0 END) AS bodytemp_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND bodytemp_mean IS NOT NULL
      THEN bodytemp_5min_n
      ELSE NULL
    END), 0)
  ) AS bodytemp_5min_profile,

    AVG(skintemp_mean) AS skintemp_mean,
    MIN(skintemp_min) AS skintemp_min,
    MAX(skintemp_max) AS skintemp_max,
    SUM(skintemp_raw_n) AS skintemp_raw_n,
    COUNT(skintemp_mean) AS skintemp_hours_n,
    SUM(skintemp_5min_n) AS skintemp_5min_n,
    AVG(CASE WHEN skintemp_mean IS NOT NULL THEN skintemp_5min_n ELSE NULL END) AS skintemp_5min_per_hour_mean,
    SUM(CASE WHEN skintemp_mean IS NOT NULL AND skintemp_5min_n = 12 THEN 1 ELSE 0 END) AS skintemp_complete_hours_n,
    JSON_ARRAY(
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 0 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 1 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 2 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 3 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 4 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 5 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 6 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 7 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 8 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 9 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 10 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 11 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 12 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 13 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 14 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 15 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 16 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 17 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 18 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 19 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 20 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 21 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 22 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0),
    COALESCE(MAX(CASE
      WHEN HOUR(bucket_hour) = 23 AND skintemp_mean IS NOT NULL
      THEN skintemp_5min_n
      ELSE NULL
    END), 0)
  ) AS skintemp_5min_profile

  FROM ranked

  GROUP BY
    userId,
    deviceId,
    firmware,
    date;

END//


DELIMITER ;
