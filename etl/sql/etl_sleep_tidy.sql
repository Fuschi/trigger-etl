-- =========================================================
-- etl_sleep_tidy.sql
--
-- Clean and deduplicated base table for sleep data.
--
-- Sleep differs from the other sensor sources because:
--   - observations are natively daily/nightly summaries
--   - the raw table does not contain event_ts
--   - the reference date is stored in separate
--     year, month and day columns
--   - deduplication is performed at daily level
--
-- One row is retained per:
--   deviceId, firmware and reference date
--
-- Operations:
--   1. Build a valid SQL DATE from year, month and day
--
--   2. Daily deduplication
--      For each (deviceId, firmware, date):
--        - identify the earliest created_at
--        - retain it only when that earliest timestamp
--          identifies exactly one raw row
--
--      Later uploads for the same date are discarded.
--      If multiple rows share the earliest created_at,
--      the date is considered ambiguous and discarded.
--
--   3. User binding
--      Keep only deviceIds associated with exactly one
--      distinct userId
--
--   4. Metric preservation
--      Sleep metrics are retained without numerical filters
--      and converted to DOUBLE for analytical consistency.
--
-- No additional temporal aggregation is performed because
-- sleep observations are already daily/nightly summaries.
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

  PRIMARY KEY (
    deviceId,
    firmware,
    date
  ),

  INDEX idx_sleep_tidy_user (
    userId
  ),

  INDEX idx_sleep_tidy_user_date (
    userId,
    date
  ),

  INDEX idx_sleep_tidy_date (
    date
  )

) ENGINE=InnoDB;


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_sleep_tidy()
BEGIN

  -- Full rebuild of the cleaned sleep table
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

    PRIMARY KEY (
      deviceId,
      firmware,
      date
    ),

    INDEX idx_sleep_tidy_user (
      userId
    ),

    INDEX idx_sleep_tidy_user_date (
      userId,
      date
    ),

    INDEX idx_sleep_tidy_date (
      date
    )

  ) ENGINE=InnoDB;


  INSERT INTO sleep_tidy (
    userId,
    deviceId,
    firmware,

    date,
    created_at,

    sleepduration,
    awake,
    insomnia,
    remsleep,
    lightsleep,
    deepsleep,
    sleepquality,
    fallsleepefficiency
  )

  WITH

  -- Step 1: construct the reference date
  --
  -- The raw sleep table stores the date components in
  -- separate year, month and day columns.
  sleep_with_date AS (
    SELECT
      t.*,

      STR_TO_DATE(
        CONCAT(
          t.year,
          '-',
          LPAD(t.month, 2, '0'),
          '-',
          LPAD(t.day, 2, '0')
        ),
        '%Y-%m-%d'
      ) AS date

    FROM sleep AS t
  ),


  -- Step 2a: find the earliest upload timestamp for each
  -- device, firmware and reference date.
  day_bucket_min_created_at AS (
    SELECT
      deviceId,
      firmware,
      date,
      MIN(created_at) AS min_created_at

    FROM sleep_with_date

    GROUP BY
      deviceId,
      firmware,
      date
  ),


  -- Step 2b: count how many rows share each created_at
  -- within the same device, firmware and date.
  --
  -- This allows us to verify that the earliest timestamp
  -- identifies one and only one raw row.
  day_bucket_created_at_counts AS (
    SELECT
      deviceId,
      firmware,
      date,
      created_at,
      COUNT(*) AS cnt

    FROM sleep_with_date

    GROUP BY
      deviceId,
      firmware,
      date,
      created_at
  ),


  -- Step 2c: retain only daily buckets whose earliest
  -- created_at is unique.
  --
  -- If several rows share the earliest timestamp, the
  -- corresponding date is considered ambiguous.
  day_bucket_unique_minimum AS (
    SELECT
      m.deviceId,
      m.firmware,
      m.date,
      m.min_created_at

    FROM day_bucket_min_created_at AS m

    JOIN day_bucket_created_at_counts AS c
      ON  c.deviceId   = m.deviceId
      AND c.firmware   = m.firmware
      AND c.date       = m.date
      AND c.created_at = m.min_created_at

    WHERE c.cnt = 1
  ),


  -- Step 2d: select the unique earliest raw record for
  -- each retained daily bucket.
  sleep_dedup AS (
    SELECT
      s.*

    FROM sleep_with_date AS s

    JOIN day_bucket_unique_minimum AS u
      ON  s.deviceId   = u.deviceId
      AND s.firmware   = u.firmware
      AND s.date       = u.date
      AND s.created_at = u.min_created_at
  ),


  -- Step 3: keep only deviceIds associated with exactly
  -- one distinct userId.
  user_sleep_unique_device AS (
    SELECT
      deviceId,
      MIN(userId) AS userId

    FROM user_sleep

    GROUP BY deviceId

    HAVING COUNT(DISTINCT userId) = 1
  )


  -- Final cleaned and deduplicated sleep dataset
  SELECT
    u.userId,
    d.deviceId,
    d.firmware,

    d.date,
    d.created_at,

    -- Metrics are preserved without validity filters.
    CAST(d.sleepduration       AS DOUBLE) AS sleepduration,
    CAST(d.awake               AS DOUBLE) AS awake,
    CAST(d.insomnia            AS DOUBLE) AS insomnia,
    CAST(d.remsleep            AS DOUBLE) AS remsleep,
    CAST(d.lightsleep          AS DOUBLE) AS lightsleep,
    CAST(d.deepsleep           AS DOUBLE) AS deepsleep,
    CAST(d.sleepquality        AS DOUBLE) AS sleepquality,
    CAST(d.fallsleepefficiency AS DOUBLE) AS fallsleepefficiency

  FROM sleep_dedup AS d

  JOIN user_sleep_unique_device AS u
    ON u.deviceId = d.deviceId;

END//


DELIMITER ;
