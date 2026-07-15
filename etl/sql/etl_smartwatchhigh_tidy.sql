-- =========================================================
-- etl_smartwatchhigh_tidy.sql
--
-- Clean base table for smartwatchhigh. No aggregation.
-- One row per valid sensor reading at minute granularity.
--
-- Operations:
--   1. Second-level deduplication
--   2. Minute-level deduplication (discard ambiguous minutes)
--   3. User binding (only deviceIds mapped to one userId)
--   4. Five-minute temporal bucket
--      Assign each retained reading to a fixed five-minute
--      interval represented by its starting timestamp:
--        10:00:00 <= event_ts < 10:05:00 -> 10:00:00
--        10:05:00 <= event_ts < 10:10:00 -> 10:05:00
--   5. Validity filters:
--        heartrate  : NULL if <= 0
--        oxygens    : NULL if outside [1, 100]
--        breathrate : NULL if outside [1, 100]
--        sleeprate  : NULL if outside [1, 4]
--                     (-1 is treated as missing/not available)
-- =========================================================


CREATE TABLE IF NOT EXISTS smartwatchhigh_tidy (

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

  heartrate  DOUBLE NULL,   -- bpm; valid: > 0
  oxygens    DOUBLE NULL,   -- SpO2 (%); valid: BETWEEN 1 AND 100
  breathrate DOUBLE NULL,   -- breaths/min; valid: BETWEEN 1 AND 100
  sleeprate  DOUBLE NULL,   -- sleep-stage code; valid: BETWEEN 1 AND 4

  PRIMARY KEY (
    deviceId,
    firmware,
    date,
    hour,
    minute
  ),

  INDEX idx_smartwatchhigh_tidy_user_date (
    userId,
    date
  ),

  INDEX idx_smartwatchhigh_tidy_user_event (
    userId,
    event_ts
  ),

  INDEX idx_smartwatchhigh_tidy_user_bucket5 (
    userId,
    bucket_5min
  ),

  INDEX idx_smartwatchhigh_tidy_date (
    date
  ),

  INDEX idx_smartwatchhigh_tidy_user_dhm (
    userId,
    date,
    hour,
    minute
  )

) ENGINE=InnoDB;


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_smartwatchhigh_tidy()
BEGIN

  -- Full rebuild of the tidy table
  DROP TABLE IF EXISTS smartwatchhigh_tidy;

  CREATE TABLE smartwatchhigh_tidy (

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

    heartrate  DOUBLE NULL,
    oxygens    DOUBLE NULL,
    breathrate DOUBLE NULL,
    sleeprate  DOUBLE NULL,

    PRIMARY KEY (
      deviceId,
      firmware,
      date,
      hour,
      minute
    ),

    INDEX idx_smartwatchhigh_tidy_user_date (
      userId,
      date
    ),

    INDEX idx_smartwatchhigh_tidy_user_event (
      userId,
      event_ts
    ),

    INDEX idx_smartwatchhigh_tidy_user_bucket5 (
      userId,
      bucket_5min
    ),

    INDEX idx_smartwatchhigh_tidy_date (
      date
    ),

    INDEX idx_smartwatchhigh_tidy_user_dhm (
      userId,
      date,
      hour,
      minute
    )

  ) ENGINE=InnoDB;


  INSERT INTO smartwatchhigh_tidy (
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
    heartrate,
    oxygens,
    breathrate,
    sleeprate
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
  swh_second_dedup AS (
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

    FROM smartwatchhigh AS s
  ),


  -- Step 2: minute-level deduplication
  --
  -- Count the valid second-level readings falling within
  -- each minute bucket.
  --
  -- Minute buckets with cnt_min > 1 are considered
  -- ambiguous and are discarded in the final WHERE clause.
  swh_dedup AS (
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

    FROM swh_second_dedup AS d

    WHERE d.created_at = d.min_ca
      AND d.cnt_ca = 1
  ),


  -- Step 3: user binding
  --
  -- Keep only deviceIds associated with exactly one userId.
  -- Devices associated with multiple users are excluded.
  user_swh_unique_device AS (
    SELECT
      deviceId,
      MIN(userId) AS userId

    FROM user_smartwatchhigh

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
      WHEN d.heartrate > 0
      THEN d.heartrate
      ELSE NULL
    END AS heartrate,

    CASE
      WHEN d.oxygens BETWEEN 1 AND 100
      THEN d.oxygens
      ELSE NULL
    END AS oxygens,

    CASE
      WHEN d.breathrate BETWEEN 1 AND 100
      THEN d.breathrate
      ELSE NULL
    END AS breathrate,

    CASE
      WHEN d.sleeprate BETWEEN 1 AND 4
      THEN d.sleeprate
      ELSE NULL
    END AS sleeprate

  FROM swh_dedup AS d

  JOIN user_swh_unique_device AS u
    ON u.deviceId = d.deviceId

  WHERE d.cnt_min = 1;

END//


DELIMITER ;
