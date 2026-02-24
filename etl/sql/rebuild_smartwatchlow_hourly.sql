USE triggerIO;

-- =========================================================
-- smartwatchlow_hourly full rebuild
-- - strict second-level de-duplication (drop ambiguous seconds)
-- - keep only deviceIds mapping to exactly one userId
-- - safe swap: build __new then RENAME TABLE
-- =========================================================

CREATE TABLE IF NOT EXISTS smartwatchlow_hourly (
  userId   BIGINT       NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  firmware VARCHAR(128) NOT NULL,
  date     DATE         NOT NULL,
  hour     TINYINT      NOT NULL,

  /* Activity */
  steps_sum        BIGINT NOT NULL,
  steps_valid_n    INT    NOT NULL,
  cal_sum          BIGINT NOT NULL,
  cal_valid_n      INT    NOT NULL,

  /* Blood pressure */
  bphigh_mean      DOUBLE NULL,
  bphigh_min       DOUBLE NULL,
  bphigh_max       DOUBLE NULL,
  bphigh_valid_n   INT    NOT NULL,

  bplow_mean       DOUBLE NULL,
  bplow_min        DOUBLE NULL,
  bplow_max        DOUBLE NULL,
  bplow_valid_n    INT    NOT NULL,

  /* Temperatures */
  bodytemp_mean    DOUBLE NULL,
  bodytemp_min     DOUBLE NULL,
  bodytemp_max     DOUBLE NULL,
  bodytemp_valid_n INT    NOT NULL,

  skintemp_mean    DOUBLE NULL,
  skintemp_min     DOUBLE NULL,
  skintemp_max     DOUBLE NULL,
  skintemp_valid_n INT    NOT NULL,

  /* Total rows contributing */
  smartwatchlow_records_n INT NOT NULL,

  PRIMARY KEY (userId, deviceId, firmware, date, hour),
  INDEX idx_smartwatchlow_hourly_date_hour (date, hour),
  INDEX idx_smartwatchlow_hourly_device (deviceId),
  INDEX idx_smartwatchlow_hourly_user (userId)
) ENGINE=InnoDB;

DELIMITER //

CREATE OR REPLACE PROCEDURE rebuild_smartwatchlow_hourly()
BEGIN
  DROP TABLE IF EXISTS smartwatchlow_hourly__new;
  CREATE TABLE smartwatchlow_hourly__new LIKE smartwatchlow_hourly;

  INSERT INTO smartwatchlow_hourly__new (
    userId, deviceId, firmware, date, hour,

    steps_sum, steps_valid_n,
    cal_sum,   cal_valid_n,

    bphigh_mean, bphigh_min, bphigh_max, bphigh_valid_n,
    bplow_mean,  bplow_min,  bplow_max,  bplow_valid_n,

    bodytemp_mean, bodytemp_min, bodytemp_max, bodytemp_valid_n,
    skintemp_mean, skintemp_min, skintemp_max, skintemp_valid_n,

    smartwatchlow_records_n
  )
  WITH
  second_bucket_min_created_at AS (
    SELECT deviceId, firmware, event_ts, MIN(created_at) AS min_created_at
    FROM smartwatchlow
    GROUP BY deviceId, firmware, event_ts
  ),
  second_bucket_created_at_counts AS (
    SELECT deviceId, firmware, event_ts, created_at, COUNT(*) AS cnt_at_created
    FROM smartwatchlow
    GROUP BY deviceId, firmware, event_ts, created_at
  ),
  second_bucket_unique_minimum AS (
    SELECT m.deviceId, m.firmware, m.event_ts, m.min_created_at
    FROM second_bucket_min_created_at AS m
    JOIN second_bucket_created_at_counts AS c
      ON  c.deviceId = m.deviceId
      AND c.firmware = m.firmware
      AND c.event_ts = m.event_ts
      AND c.created_at = m.min_created_at
    WHERE c.cnt_at_created = 1
  ),
  smartwatchlow_strict_second_dedup AS (
    SELECT y.*
    FROM smartwatchlow AS y
    JOIN second_bucket_unique_minimum AS u
      ON  y.deviceId = u.deviceId
      AND y.firmware = u.firmware
      AND y.event_ts = u.event_ts
      AND y.created_at = u.min_created_at
  ),
  user_smartwatchlow_unique_device AS (
    SELECT deviceId, MIN(userId) AS userId
    FROM user_smartwatchlow
    GROUP BY deviceId
    HAVING COUNT(DISTINCT userId) = 1
  ),
  smartwatchlow_strict_second_dedup_with_user AS (
    SELECT d.*, u.userId
    FROM smartwatchlow_strict_second_dedup AS d
    JOIN user_smartwatchlow_unique_device AS u
      ON u.deviceId = d.deviceId
  )
  SELECT
    d.userId,
    d.deviceId,
    d.firmware,
    DATE(d.event_ts) AS date,
    HOUR(d.event_ts) AS hour,

    /* Steps (>=0 valid) */
    SUM(CASE WHEN d.step >= 0 THEN d.step ELSE 0 END) AS steps_sum,
    SUM(CASE WHEN d.step >= 0 THEN 1 ELSE 0 END)       AS steps_valid_n,

    /* Calories (>=0 valid) */
    SUM(CASE WHEN d.cal >= 0 THEN d.cal ELSE 0 END) AS cal_sum,
    SUM(CASE WHEN d.cal >= 0 THEN 1 ELSE 0 END)     AS cal_valid_n,

    /* Blood pressure (>0 valid) */
    CAST(AVG(CASE WHEN d.bphigh > 0 THEN d.bphigh END) AS DOUBLE) AS bphigh_mean,
    CAST(MIN(CASE WHEN d.bphigh > 0 THEN d.bphigh END) AS DOUBLE) AS bphigh_min,
    CAST(MAX(CASE WHEN d.bphigh > 0 THEN d.bphigh END) AS DOUBLE) AS bphigh_max,
    SUM(CASE WHEN d.bphigh > 0 THEN 1 ELSE 0 END) AS bphigh_valid_n,

    CAST(AVG(CASE WHEN d.bplow > 0 THEN d.bplow END) AS DOUBLE) AS bplow_mean,
    CAST(MIN(CASE WHEN d.bplow > 0 THEN d.bplow END) AS DOUBLE) AS bplow_min,
    CAST(MAX(CASE WHEN d.bplow > 0 THEN d.bplow END) AS DOUBLE) AS bplow_max,
    SUM(CASE WHEN d.bplow > 0 THEN 1 ELSE 0 END) AS bplow_valid_n,

    /* Body temperature (>0 valid) */
    CAST(AVG(CASE WHEN d.bodytemp > 0 THEN d.bodytemp END) AS DOUBLE) AS bodytemp_mean,
    CAST(MIN(CASE WHEN d.bodytemp > 0 THEN d.bodytemp END) AS DOUBLE) AS bodytemp_min,
    CAST(MAX(CASE WHEN d.bodytemp > 0 THEN d.bodytemp END) AS DOUBLE) AS bodytemp_max,
    SUM(CASE WHEN d.bodytemp > 0 THEN 1 ELSE 0 END) AS bodytemp_valid_n,

    /* Skin temperature (>0 valid) */
    CAST(AVG(CASE WHEN d.skintemp > 0 THEN d.skintemp END) AS DOUBLE) AS skintemp_mean,
    CAST(MIN(CASE WHEN d.skintemp > 0 THEN d.skintemp END) AS DOUBLE) AS skintemp_min,
    CAST(MAX(CASE WHEN d.skintemp > 0 THEN d.skintemp END) AS DOUBLE) AS skintemp_max,
    SUM(CASE WHEN d.skintemp > 0 THEN 1 ELSE 0 END) AS skintemp_valid_n,

    /* Total rows after strict dedup + user binding */
    COUNT(*) AS smartwatchlow_records_n

  FROM smartwatchlow_strict_second_dedup_with_user AS d
  GROUP BY d.userId, d.deviceId, d.firmware, DATE(d.event_ts), HOUR(d.event_ts);

  DROP TABLE IF EXISTS smartwatchlow_hourly__old;
  RENAME TABLE smartwatchlow_hourly TO smartwatchlow_hourly__old,
               smartwatchlow_hourly__new TO smartwatchlow_hourly;
  DROP TABLE IF EXISTS smartwatchlow_hourly__old;
END//

DELIMITER ;