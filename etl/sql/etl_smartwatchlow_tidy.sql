-- =========================================================
-- etl_smartwatchlow_tidy.sql
--
-- Clean and deduplicated base table for smartwatchlow.
-- No temporal aggregation.
-- One row per valid sensor reading at minute granularity.
--
-- Operations:
--   1. Second-level deduplication
--      For each (deviceId, firmware, event_ts):
--        keep the row with MIN(created_at) only if unique
--
--   2. Minute-level deduplication
--      Discard any minute bucket containing more than one
--      valid reading after second-level deduplication
--
--   3. User binding
--      Keep only deviceIds mapped to exactly one userId
--
--   4. Five-minute temporal bucket
--      Assign each retained reading to a fixed five-minute
--      interval represented by its starting timestamp:
--        10:00:00 <= event_ts < 10:05:00 -> 10:00:00
--        10:05:00 <= event_ts < 10:10:00 -> 10:05:00
--
--   5. Validity filters and transformations
--        step, cal  : NULL if < 0
--        bphigh     : GREATEST(bphigh, bplow) when both > 0
--        bplow      : LEAST(bphigh, bplow) when both > 0
--        bodytemp   : preserved as recorded; no validity filter
--        skintemp   : preserved as recorded; no validity filter
-- =========================================================


CREATE TABLE IF NOT EXISTS smartwatchlow_tidy (

  userId   BIGINT       NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  firmware VARCHAR(128) NOT NULL,

  event_ts    DATETIME NOT NULL,
  created_at  DATETIME NOT NULL,
  bucket_5min DATETIME NOT NULL,
  date        DATE     NOT NULL,
  hour        TINYINT  NOT NULL,
  minute      TINYINT  NOT NULL,
  `second`    TINYINT  NOT NULL,

  step DOUBLE NULL,  -- valid: >= 0
  cal  DOUBLE NULL,  -- valid: >= 0

  -- Blood-pressure values are reordered when both are positive:
  -- the greater value is stored as bphigh and the lower as bplow.
  bphigh DOUBLE NULL,
  bplow  DOUBLE NULL,

  -- Temperature values are preserved as recorded.
  bodytemp DOUBLE NULL,
  skintemp DOUBLE NULL,

  PRIMARY KEY (
    deviceId,
    firmware,
    date,
    hour,
    minute
  ),

  INDEX idx_smartwatchlow_tidy_user_date (
    userId,
    date
  ),

  INDEX idx_smartwatchlow_tidy_user_event (
    userId,
    event_ts
  ),

  INDEX idx_smartwatchlow_tidy_user_bucket5 (
    userId,
    bucket_5min
  ),

  INDEX idx_smartwatchlow_tidy_date (
    date
  ),

  INDEX idx_smartwatchlow_tidy_user_dhm (
    userId,
    date,
    hour,
    minute
  )

) ENGINE=InnoDB;


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_smartwatchlow_tidy()
BEGIN

  -- Full rebuild of the tidy table
  DROP TABLE IF EXISTS smartwatchlow_tidy;

  CREATE TABLE smartwatchlow_tidy (

    userId   BIGINT       NOT NULL,
    deviceId VARCHAR(128) NOT NULL,
    firmware VARCHAR(128) NOT NULL,

    event_ts    DATETIME NOT NULL,
    created_at  DATETIME NOT NULL,
    bucket_5min DATETIME NOT NULL,
    date        DATE     NOT NULL,
    hour        TINYINT  NOT NULL,
    minute      TINYINT  NOT NULL,
    `second`    TINYINT  NOT NULL,

    step     DOUBLE NULL,
    cal      DOUBLE NULL,
    bphigh   DOUBLE NULL,
    bplow    DOUBLE NULL,
    bodytemp DOUBLE NULL,
    skintemp DOUBLE NULL,

    PRIMARY KEY (
      deviceId,
      firmware,
      date,
      hour,
      minute
    ),

    INDEX idx_smartwatchlow_tidy_user_date (
      userId,
      date
    ),

    INDEX idx_smartwatchlow_tidy_user_event (
      userId,
      event_ts
    ),

    INDEX idx_smartwatchlow_tidy_user_bucket5 (
      userId,
      bucket_5min
    ),

    INDEX idx_smartwatchlow_tidy_date (
      date
    ),

    INDEX idx_smartwatchlow_tidy_user_dhm (
      userId,
      date,
      hour,
      minute
    )

  ) ENGINE=InnoDB;


  INSERT INTO smartwatchlow_tidy (
    userId,
    deviceId,
    firmware,
    event_ts,
    created_at,
    bucket_5min,
    date,
    hour,
    minute,
    `second`,
    step,
    cal,
    bphigh,
    bplow,
    bodytemp,
    skintemp
  )

  WITH

  -- Step 1: second-level deduplication
  --
  -- min_ca:
  --   earliest created_at for each
  --   (deviceId, firmware, event_ts)
  --
  -- cnt_ca:
  --   number of rows sharing the same created_at within
  --   the same (deviceId, firmware, event_ts)
  --
  -- Keep only rows where:
  --   created_at = min_ca
  --   cnt_ca = 1
  swl_second_dedup AS (
    SELECT
      s.*,

      MIN(s.created_at) OVER (
        PARTITION BY
          s.deviceId,
          s.firmware,
          s.event_ts
      ) AS min_ca,

      COUNT(*) OVER (
        PARTITION BY
          s.deviceId,
          s.firmware,
          s.event_ts,
          s.created_at
      ) AS cnt_ca

    FROM smartwatchlow AS s
  ),


  -- Step 2: minute-level deduplication
  --
  -- Count the valid second-level readings falling within
  -- each minute bucket.
  --
  -- Minute buckets with cnt_min > 1 are considered
  -- ambiguous and are discarded in the final WHERE clause.
  swl_dedup AS (
    SELECT
      d.*,

      COUNT(*) OVER (
        PARTITION BY
          d.deviceId,
          d.firmware,
          DATE(d.event_ts),
          HOUR(d.event_ts),
          MINUTE(d.event_ts)
      ) AS cnt_min

    FROM swl_second_dedup AS d

    WHERE d.created_at = d.min_ca
      AND d.cnt_ca = 1
  ),


  -- Step 3: user binding
  --
  -- Keep only deviceIds associated with exactly one userId.
  -- Devices associated with multiple users are excluded.
  user_swl_unique_device AS (
    SELECT
      deviceId,
      MIN(userId) AS userId

    FROM user_smartwatchlow

    GROUP BY deviceId

    HAVING COUNT(DISTINCT userId) = 1
  )


  -- Final cleaned and deduplicated dataset
  SELECT
    u.userId     AS userId,
    d.deviceId   AS deviceId,
    d.firmware   AS firmware,
    d.event_ts   AS event_ts,
    d.created_at AS created_at,

    -- Beginning of the fixed five-minute interval
    TIMESTAMP(
      DATE(d.event_ts),
      MAKETIME(
        HOUR(d.event_ts),
        (MINUTE(d.event_ts) DIV 5) * 5,
        0
      )
    ) AS bucket_5min,

    DATE(d.event_ts)   AS date,
    HOUR(d.event_ts)   AS hour,
    MINUTE(d.event_ts) AS minute,
    SECOND(d.event_ts) AS `second`,

    CASE
      WHEN d.step >= 0
      THEN d.step
      ELSE NULL
    END AS step,

    CASE
      WHEN d.cal >= 0
      THEN d.cal
      ELSE NULL
    END AS cal,

    -- When both values are positive, store the greater
    -- value as systolic pressure.
    CASE
      WHEN d.bphigh > 0
       AND d.bplow > 0
      THEN GREATEST(d.bphigh, d.bplow)
      ELSE NULL
    END AS bphigh,

    -- When both values are positive, store the lower
    -- value as diastolic pressure.
    CASE
      WHEN d.bphigh > 0
       AND d.bplow > 0
      THEN LEAST(d.bphigh, d.bplow)
      ELSE NULL
    END AS bplow,

    -- No validity filters are applied to temperatures.
    d.bodytemp AS bodytemp,
    d.skintemp AS skintemp

  FROM swl_dedup AS d

  JOIN user_swl_unique_device AS u
    ON u.deviceId = d.deviceId

  WHERE d.cnt_min = 1;

END//


DELIMITER ;
