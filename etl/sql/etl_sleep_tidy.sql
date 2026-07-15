-- =========================================================
-- sleep_tidy.sql
--
-- Clean base table for sleep. One row per night.
--
-- Differs from other sensors:
--   - Raw table has no event_ts: date is built from
--     separate year, month, day columns
--   - Deduplication is at DAY level (not second level)
--
-- Operations:
--   1. Build date column from year/month/day
--   2. Strict day-level deduplication
--   3. User binding (only deviceIds mapped to one userId)
-- =========================================================

CREATE TABLE IF NOT EXISTS sleep_tidy (

  userId   BIGINT       NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  firmware VARCHAR(128) NOT NULL,

  date       DATE     NOT NULL,
  created_at DATETIME NOT NULL,

  sleepduration       DOUBLE NULL,
  awake               DOUBLE NULL,
  insomnia            DOUBLE NULL,
  remsleep            DOUBLE NULL,
  lightsleep          DOUBLE NULL,
  deepsleep           DOUBLE NULL,
  sleepquality        DOUBLE NULL,
  fallsleepefficiency DOUBLE NULL,

  PRIMARY KEY (deviceId, firmware, date),

  INDEX idx_sleep_tidy_user      (userId),
  INDEX idx_sleep_tidy_user_date (userId, date),
  INDEX idx_sleep_tidy_date      (date)

) ENGINE=InnoDB;


DELIMITER //

CREATE OR REPLACE PROCEDURE etl_sleep_tidy()
BEGIN

  DROP TABLE IF EXISTS sleep_tidy;

  CREATE TABLE sleep_tidy (

    userId   BIGINT       NOT NULL,
    deviceId VARCHAR(128) NOT NULL,
    firmware VARCHAR(128) NOT NULL,

    date       DATE     NOT NULL,
    created_at DATETIME NOT NULL,

    sleepduration       DOUBLE NULL,
    awake               DOUBLE NULL,
    insomnia            DOUBLE NULL,
    remsleep            DOUBLE NULL,
    lightsleep          DOUBLE NULL,
    deepsleep           DOUBLE NULL,
    sleepquality        DOUBLE NULL,
    fallsleepefficiency DOUBLE NULL,

    PRIMARY KEY (deviceId, firmware, date),

    INDEX idx_sleep_tidy_user      (userId),
    INDEX idx_sleep_tidy_user_date (userId, date),
    INDEX idx_sleep_tidy_date      (date)

  ) ENGINE=InnoDB;


  INSERT INTO sleep_tidy (
    userId, deviceId, firmware,
    date, created_at,
    sleepduration, awake, insomnia, remsleep,
    lightsleep, deepsleep, sleepquality, fallsleepefficiency
  )
  WITH
  sleep_with_date AS (
    SELECT
      t.*,
      STR_TO_DATE(
        CONCAT(t.year, '-', LPAD(t.month, 2, '0'), '-', LPAD(t.day, 2, '0')),
        '%Y-%m-%d'
      ) AS date
    FROM sleep AS t
  ),
  day_bucket_min_created_at AS (
    SELECT deviceId, firmware, date,
           MIN(created_at) AS min_created_at
    FROM   sleep_with_date
    GROUP  BY deviceId, firmware, date
  ),
  day_bucket_created_at_counts AS (
    SELECT deviceId, firmware, date, created_at,
           COUNT(*) AS cnt
    FROM   sleep_with_date
    GROUP  BY deviceId, firmware, date, created_at
  ),
  day_bucket_unique_minimum AS (
    SELECT m.deviceId, m.firmware, m.date, m.min_created_at
    FROM   day_bucket_min_created_at    AS m
    JOIN   day_bucket_created_at_counts AS c
           ON  c.deviceId   = m.deviceId
           AND c.firmware   = m.firmware
           AND c.date       = m.date
           AND c.created_at = m.min_created_at
    WHERE  c.cnt = 1
  ),
  sleep_dedup AS (
    SELECT s.*
    FROM   sleep_with_date AS s
    JOIN   day_bucket_unique_minimum AS u
           ON  s.deviceId   = u.deviceId
           AND s.firmware   = u.firmware
           AND s.date       = u.date
           AND s.created_at = u.min_created_at
  ),
  user_sleep_unique_device AS (
    SELECT deviceId, MIN(userId) AS userId
    FROM   user_sleep
    GROUP  BY deviceId
    HAVING COUNT(DISTINCT userId) = 1
  )
  SELECT
    u.userId,
    d.deviceId,
    d.firmware,
    d.date,
    d.created_at,
    CAST(d.sleepduration       AS DOUBLE),
    CAST(d.awake               AS DOUBLE),
    CAST(d.insomnia            AS DOUBLE),
    CAST(d.remsleep            AS DOUBLE),
    CAST(d.lightsleep          AS DOUBLE),
    CAST(d.deepsleep           AS DOUBLE),
    CAST(d.sleepquality        AS DOUBLE),
    CAST(d.fallsleepefficiency AS DOUBLE)
  FROM      sleep_dedup              AS d
  JOIN      user_sleep_unique_device AS u ON u.deviceId = d.deviceId;


END//

DELIMITER ;
