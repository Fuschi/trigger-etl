-- =========================================================
-- etl_myair_tidy.sql
--
-- Clean and deduplicated base table for MyAir data.
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
--   5. Validity filters
--        pm*, pc*    : NULL if outside [0, 65534]
--                      (65535 is treated as a sensor error code)
--        temperature : preserved as recorded; no validity filter
--        humidity    : NULL if outside [0, 100] %RH
--        pressure    : NULL if outside [300, 1100] hPa
--        sound       : NULL if outside [0, 200]
--        uvb         : NULL if outside [0, 6552]
--                      (6553 is an observed error/missing-value code)
--        light       : NULL if < 0
-- =========================================================


CREATE TABLE IF NOT EXISTS myair_tidy (

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

  -- Particulate mass (µg/m³)
  -- Valid: BETWEEN 0 AND 65534
  pm1  DOUBLE NULL,
  pm25 DOUBLE NULL,
  pm10 DOUBLE NULL,

  -- Particle counts (#/dL)
  -- Valid: BETWEEN 0 AND 65534
  pc03 DOUBLE NULL,
  pc05 DOUBLE NULL,
  pc1  DOUBLE NULL,
  pc25 DOUBLE NULL,
  pc5  DOUBLE NULL,
  pc10 DOUBLE NULL,

  -- Environmental measurements
  temperature DOUBLE NULL,  -- preserved as recorded; no validity filter
  humidity    DOUBLE NULL,  -- valid: BETWEEN 0 AND 100 (%RH)
  pressure    DOUBLE NULL,  -- valid: BETWEEN 300 AND 1100 (hPa)
  sound       DOUBLE NULL,  -- valid: BETWEEN 0 AND 200
  uvb         DOUBLE NULL,  -- valid: BETWEEN 0 AND 6552; observed error code: 6553
  light       DOUBLE NULL,  -- valid: >= 0

  PRIMARY KEY (
    deviceId,
    firmware,
    date,
    hour,
    minute
  ),

  INDEX idx_myair_tidy_user_date (
    userId,
    date
  ),

  INDEX idx_myair_tidy_user_event (
    userId,
    event_ts
  ),

  INDEX idx_myair_tidy_user_bucket5 (
    userId,
    bucket_5min
  ),

  INDEX idx_myair_tidy_date (
    date
  ),

  INDEX idx_myair_tidy_user_dhm (
    userId,
    date,
    hour,
    minute
  )

) ENGINE=InnoDB;


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_myair_tidy()
BEGIN

  -- Full rebuild of the tidy table
  DROP TABLE IF EXISTS myair_tidy;

  CREATE TABLE myair_tidy (

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

    pm1  DOUBLE NULL,
    pm25 DOUBLE NULL,
    pm10 DOUBLE NULL,

    pc03 DOUBLE NULL,
    pc05 DOUBLE NULL,
    pc1  DOUBLE NULL,
    pc25 DOUBLE NULL,
    pc5  DOUBLE NULL,
    pc10 DOUBLE NULL,

    temperature DOUBLE NULL,
    humidity    DOUBLE NULL,
    pressure    DOUBLE NULL,
    sound       DOUBLE NULL,
    uvb         DOUBLE NULL,
    light       DOUBLE NULL,

    PRIMARY KEY (
      deviceId,
      firmware,
      date,
      hour,
      minute
    ),

    INDEX idx_myair_tidy_user_date (
      userId,
      date
    ),

    INDEX idx_myair_tidy_user_event (
      userId,
      event_ts
    ),

    INDEX idx_myair_tidy_user_bucket5 (
      userId,
      bucket_5min
    ),

    INDEX idx_myair_tidy_date (
      date
    ),

    INDEX idx_myair_tidy_user_dhm (
      userId,
      date,
      hour,
      minute
    )

  ) ENGINE=InnoDB;


  INSERT INTO myair_tidy (
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
    pm1,
    pm25,
    pm10,
    pc03,
    pc05,
    pc1,
    pc25,
    pc5,
    pc10,
    temperature,
    humidity,
    pressure,
    sound,
    uvb,
    light
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
  myair_second_dedup AS (
    SELECT
      m.*,

      MIN(m.created_at) OVER (
        PARTITION BY
          m.deviceId,
          m.firmware,
          m.event_ts
      ) AS min_ca,

      COUNT(*) OVER (
        PARTITION BY
          m.deviceId,
          m.firmware,
          m.event_ts,
          m.created_at
      ) AS cnt_ca

    FROM myair AS m
  ),


  -- Step 2: minute-level deduplication
  --
  -- Count the valid second-level records falling within
  -- each minute bucket.
  --
  -- Minute buckets with cnt_min > 1 are ambiguous and
  -- are discarded in the final WHERE clause.
  myair_dedup AS (
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

    FROM myair_second_dedup AS d

    WHERE d.created_at = d.min_ca
      AND d.cnt_ca = 1
  ),


  -- Step 3: user binding
  --
  -- Keep only deviceIds associated with exactly one userId.
  -- Devices associated with multiple users are excluded.
  user_myair_unique_device AS (
    SELECT
      deviceId,
      MIN(userId) AS userId

    FROM user_myair

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
      WHEN d.pm1 BETWEEN 0 AND 65534
      THEN d.pm1
      ELSE NULL
    END AS pm1,

    CASE
      WHEN d.pm25 BETWEEN 0 AND 65534
      THEN d.pm25
      ELSE NULL
    END AS pm25,

    CASE
      WHEN d.pm10 BETWEEN 0 AND 65534
      THEN d.pm10
      ELSE NULL
    END AS pm10,

    CASE
      WHEN d.pc03 BETWEEN 0 AND 65534
      THEN d.pc03
      ELSE NULL
    END AS pc03,

    CASE
      WHEN d.pc05 BETWEEN 0 AND 65534
      THEN d.pc05
      ELSE NULL
    END AS pc05,

    CASE
      WHEN d.pc1 BETWEEN 0 AND 65534
      THEN d.pc1
      ELSE NULL
    END AS pc1,

    CASE
      WHEN d.pc25 BETWEEN 0 AND 65534
      THEN d.pc25
      ELSE NULL
    END AS pc25,

    CASE
      WHEN d.pc5 BETWEEN 0 AND 65534
      THEN d.pc5
      ELSE NULL
    END AS pc5,

    CASE
      WHEN d.pc10 BETWEEN 0 AND 65534
      THEN d.pc10
      ELSE NULL
    END AS pc10,

    -- No validity filter is applied to temperature
    d.temperature AS temperature,

    CASE
      WHEN d.humidity BETWEEN 0 AND 100
      THEN d.humidity
      ELSE NULL
    END AS humidity,

    CASE
      WHEN d.pressure BETWEEN 300 AND 1100
      THEN d.pressure
      ELSE NULL
    END AS pressure,

    CASE
      WHEN d.sound BETWEEN 0 AND 200
      THEN d.sound
      ELSE NULL
    END AS sound,

    CASE
      WHEN d.uvb BETWEEN 0 AND 6552
      THEN d.uvb
      ELSE NULL
    END AS uvb,

    CASE
      WHEN d.light >= 0
      THEN d.light
      ELSE NULL
    END AS light

  FROM myair_dedup AS d

  JOIN user_myair_unique_device AS u
    ON u.deviceId = d.deviceId

  WHERE d.cnt_min = 1;

END//


DELIMITER ;
