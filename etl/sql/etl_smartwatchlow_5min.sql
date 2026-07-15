-- =========================================================
-- etl_smartwatchlow_5min.sql
--
-- Materialized five-minute aggregation of
-- smartwatchlow_tidy.
--
-- One row per device, firmware and fixed five-minute bucket.
--
-- Each bucket is represented by its starting timestamp:
--   10:00:00 <= event_ts < 10:05:00 -> 10:00:00
--   10:05:00 <= event_ts < 10:10:00 -> 10:05:00
--
-- Continuous physiological measurements:
--   mean  : arithmetic mean of valid readings
--   min   : minimum valid reading
--   max   : maximum valid reading
--   raw_n : number of valid readings
--
-- The exact semantics of step and cal still need to be
-- verified. They may be increments or cumulative counters.
--
-- For this reason, the five-minute table retains:
--   mean
--   min
--   max
--   sum
--   first valid value
--   last valid value
--   raw_n
--
-- No step or calorie delta is calculated at this stage.
-- raw_n values must not be used as weights in hourly or
-- daily temporal averages.
-- =========================================================


CREATE TABLE IF NOT EXISTS smartwatchlow_5min (

  userId   BIGINT       NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  firmware VARCHAR(128) NOT NULL,

  bucket_5min DATETIME NOT NULL,
  date        DATE     NOT NULL,
  hour        TINYINT  NOT NULL,
  minute      TINYINT  NOT NULL,

  -- Total tidy records within the five-minute interval
  records_n SMALLINT UNSIGNED NOT NULL,

  -- Steps: semantics still to be verified
  step_mean  DOUBLE NULL,
  step_min   DOUBLE NULL,
  step_max   DOUBLE NULL,
  step_sum   DOUBLE NULL,
  step_first DOUBLE NULL,
  step_last  DOUBLE NULL,
  step_raw_n SMALLINT UNSIGNED NOT NULL,

  -- Calories: semantics still to be verified
  cal_mean  DOUBLE NULL,
  cal_min   DOUBLE NULL,
  cal_max   DOUBLE NULL,
  cal_sum   DOUBLE NULL,
  cal_first DOUBLE NULL,
  cal_last  DOUBLE NULL,
  cal_raw_n SMALLINT UNSIGNED NOT NULL,

  bphigh_mean  DOUBLE NULL,
  bphigh_min   DOUBLE NULL,
  bphigh_max   DOUBLE NULL,
  bphigh_raw_n SMALLINT UNSIGNED NOT NULL,

  bplow_mean  DOUBLE NULL,
  bplow_min   DOUBLE NULL,
  bplow_max   DOUBLE NULL,
  bplow_raw_n SMALLINT UNSIGNED NOT NULL,

  bodytemp_mean  DOUBLE NULL,
  bodytemp_min   DOUBLE NULL,
  bodytemp_max   DOUBLE NULL,
  bodytemp_raw_n SMALLINT UNSIGNED NOT NULL,

  skintemp_mean  DOUBLE NULL,
  skintemp_min   DOUBLE NULL,
  skintemp_max   DOUBLE NULL,
  skintemp_raw_n SMALLINT UNSIGNED NOT NULL,

  PRIMARY KEY (
    deviceId,
    firmware,
    bucket_5min
  ),

  INDEX idx_smartwatchlow_5min_user_bucket5 (
    userId,
    bucket_5min
  ),

  INDEX idx_smartwatchlow_5min_bucket5 (
    bucket_5min
  ),

  INDEX idx_smartwatchlow_5min_date (
    date
  )

) ENGINE=InnoDB;


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_smartwatchlow_5min()
BEGIN

  -- Full rebuild of the materialized five-minute table
  DROP TABLE IF EXISTS smartwatchlow_5min;

  CREATE TABLE smartwatchlow_5min (

    userId   BIGINT       NOT NULL,
    deviceId VARCHAR(128) NOT NULL,
    firmware VARCHAR(128) NOT NULL,

    bucket_5min DATETIME NOT NULL,
    date        DATE     NOT NULL,
    hour        TINYINT  NOT NULL,
    minute      TINYINT  NOT NULL,

    records_n SMALLINT UNSIGNED NOT NULL,

    step_mean  DOUBLE NULL,
    step_min   DOUBLE NULL,
    step_max   DOUBLE NULL,
    step_sum   DOUBLE NULL,
    step_first DOUBLE NULL,
    step_last  DOUBLE NULL,
    step_raw_n SMALLINT UNSIGNED NOT NULL,

    cal_mean  DOUBLE NULL,
    cal_min   DOUBLE NULL,
    cal_max   DOUBLE NULL,
    cal_sum   DOUBLE NULL,
    cal_first DOUBLE NULL,
    cal_last  DOUBLE NULL,
    cal_raw_n SMALLINT UNSIGNED NOT NULL,

    bphigh_mean  DOUBLE NULL,
    bphigh_min   DOUBLE NULL,
    bphigh_max   DOUBLE NULL,
    bphigh_raw_n SMALLINT UNSIGNED NOT NULL,

    bplow_mean  DOUBLE NULL,
    bplow_min   DOUBLE NULL,
    bplow_max   DOUBLE NULL,
    bplow_raw_n SMALLINT UNSIGNED NOT NULL,

    bodytemp_mean  DOUBLE NULL,
    bodytemp_min   DOUBLE NULL,
    bodytemp_max   DOUBLE NULL,
    bodytemp_raw_n SMALLINT UNSIGNED NOT NULL,

    skintemp_mean  DOUBLE NULL,
    skintemp_min   DOUBLE NULL,
    skintemp_max   DOUBLE NULL,
    skintemp_raw_n SMALLINT UNSIGNED NOT NULL,

    PRIMARY KEY (
      deviceId,
      firmware,
      bucket_5min
    ),

    INDEX idx_smartwatchlow_5min_user_bucket5 (
      userId,
      bucket_5min
    ),

    INDEX idx_smartwatchlow_5min_bucket5 (
      bucket_5min
    ),

    INDEX idx_smartwatchlow_5min_date (
      date
    )

  ) ENGINE=InnoDB;


  INSERT INTO smartwatchlow_5min (
    userId,
    deviceId,
    firmware,

    bucket_5min,
    date,
    hour,
    minute,

    records_n,

    step_mean,
    step_min,
    step_max,
    step_sum,
    step_first,
    step_last,
    step_raw_n,

    cal_mean,
    cal_min,
    cal_max,
    cal_sum,
    cal_first,
    cal_last,
    cal_raw_n,

    bphigh_mean,
    bphigh_min,
    bphigh_max,
    bphigh_raw_n,

    bplow_mean,
    bplow_min,
    bplow_max,
    bplow_raw_n,

    bodytemp_mean,
    bodytemp_min,
    bodytemp_max,
    bodytemp_raw_n,

    skintemp_mean,
    skintemp_min,
    skintemp_max,
    skintemp_raw_n
  )

  WITH swl_bucket_values AS (
    SELECT
      s.*,

      -- Earliest valid step value in the bucket
      FIRST_VALUE(s.step) OVER (
        PARTITION BY
          s.userId,
          s.deviceId,
          s.firmware,
          s.bucket_5min

        ORDER BY
          (s.step IS NULL),
          s.event_ts,
          s.created_at
      ) AS step_first_value,

      -- Latest valid step value in the bucket
      FIRST_VALUE(s.step) OVER (
        PARTITION BY
          s.userId,
          s.deviceId,
          s.firmware,
          s.bucket_5min

        ORDER BY
          (s.step IS NULL),
          s.event_ts DESC,
          s.created_at DESC
      ) AS step_last_value,

      -- Earliest valid calorie value in the bucket
      FIRST_VALUE(s.cal) OVER (
        PARTITION BY
          s.userId,
          s.deviceId,
          s.firmware,
          s.bucket_5min

        ORDER BY
          (s.cal IS NULL),
          s.event_ts,
          s.created_at
      ) AS cal_first_value,

      -- Latest valid calorie value in the bucket
      FIRST_VALUE(s.cal) OVER (
        PARTITION BY
          s.userId,
          s.deviceId,
          s.firmware,
          s.bucket_5min

        ORDER BY
          (s.cal IS NULL),
          s.event_ts DESC,
          s.created_at DESC
      ) AS cal_last_value

    FROM smartwatchlow_tidy AS s
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

    AVG(step)               AS step_mean,
    MIN(step)               AS step_min,
    MAX(step)               AS step_max,
    SUM(step)               AS step_sum,
    MAX(step_first_value)   AS step_first,
    MAX(step_last_value)    AS step_last,
    COUNT(step)             AS step_raw_n,

    AVG(cal)                AS cal_mean,
    MIN(cal)                AS cal_min,
    MAX(cal)                AS cal_max,
    SUM(cal)                AS cal_sum,
    MAX(cal_first_value)    AS cal_first,
    MAX(cal_last_value)     AS cal_last,
    COUNT(cal)              AS cal_raw_n,

    AVG(bphigh)   AS bphigh_mean,
    MIN(bphigh)   AS bphigh_min,
    MAX(bphigh)   AS bphigh_max,
    COUNT(bphigh) AS bphigh_raw_n,

    AVG(bplow)   AS bplow_mean,
    MIN(bplow)   AS bplow_min,
    MAX(bplow)   AS bplow_max,
    COUNT(bplow) AS bplow_raw_n,

    AVG(bodytemp)   AS bodytemp_mean,
    MIN(bodytemp)   AS bodytemp_min,
    MAX(bodytemp)   AS bodytemp_max,
    COUNT(bodytemp) AS bodytemp_raw_n,

    AVG(skintemp)   AS skintemp_mean,
    MIN(skintemp)   AS skintemp_min,
    MAX(skintemp)   AS skintemp_max,
    COUNT(skintemp) AS skintemp_raw_n

  FROM swl_bucket_values

  GROUP BY
    userId,
    deviceId,
    firmware,
    bucket_5min;

END//


DELIMITER ;
