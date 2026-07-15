-- =========================================================
-- etl_gps_tidy.sql
--
-- Clean and deduplicated base table for GPS data.
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
--        longitude, latitude:
--          both set to NULL unless longitude is within
--          [-180, 180] and latitude is within [-90, 90]
--        accuracy:
--          preserved as recorded; no validity filter
-- =========================================================


CREATE TABLE IF NOT EXISTS gps_tidy (

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

  longitude DOUBLE NULL,  -- valid coordinate pair: longitude [-180, 180]
  latitude  DOUBLE NULL,  -- valid coordinate pair: latitude [-90, 90]
  accuracy  DOUBLE NULL,  -- preserved as recorded; no validity filter

  PRIMARY KEY (
    deviceId,
    firmware,
    date,
    hour,
    minute
  ),

  INDEX idx_gps_tidy_user_date (
    userId,
    date
  ),

  INDEX idx_gps_tidy_user_event (
    userId,
    event_ts
  ),

  INDEX idx_gps_tidy_user_bucket5 (
    userId,
    bucket_5min
  ),

  INDEX idx_gps_tidy_date (
    date
  ),

  INDEX idx_gps_tidy_user_dhm (
    userId,
    date,
    hour,
    minute
  )

) ENGINE=InnoDB;


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_gps_tidy()
BEGIN

  -- Full rebuild of the tidy table
  DROP TABLE IF EXISTS gps_tidy;

  CREATE TABLE gps_tidy (

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

    longitude DOUBLE NULL,
    latitude  DOUBLE NULL,
    accuracy  DOUBLE NULL,

    PRIMARY KEY (
      deviceId,
      firmware,
      date,
      hour,
      minute
    ),

    INDEX idx_gps_tidy_user_date (
      userId,
      date
    ),

    INDEX idx_gps_tidy_user_event (
      userId,
      event_ts
    ),

    INDEX idx_gps_tidy_user_bucket5 (
      userId,
      bucket_5min
    ),

    INDEX idx_gps_tidy_date (
      date
    ),

    INDEX idx_gps_tidy_user_dhm (
      userId,
      date,
      hour,
      minute
    )

  ) ENGINE=InnoDB;


  INSERT INTO gps_tidy (
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
    longitude,
    latitude,
    accuracy
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
  gps_second_dedup AS (
    SELECT
      g.*,

      MIN(g.created_at) OVER (
        PARTITION BY
          g.deviceId,
          g.firmware,
          g.event_ts
      ) AS min_ca,

      COUNT(*) OVER (
        PARTITION BY
          g.deviceId,
          g.firmware,
          g.event_ts,
          g.created_at
      ) AS cnt_ca

    FROM gps AS g
  ),


  -- Step 2: minute-level deduplication
  --
  -- Count the valid second-level readings falling within
  -- each minute bucket.
  --
  -- Minute buckets with cnt_min > 1 are considered
  -- ambiguous and are discarded in the final WHERE clause.
  gps_dedup AS (
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

    FROM gps_second_dedup AS d

    WHERE d.created_at = d.min_ca
      AND d.cnt_ca = 1
  ),


  -- Step 3: user binding
  --
  -- Keep only deviceIds associated with exactly one userId.
  -- Devices associated with multiple users are excluded.
  user_gps_unique_device AS (
    SELECT
      deviceId,
      MIN(userId) AS userId

    FROM user_gps

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

    -- Longitude and latitude are treated as a coordinate pair.
    -- If either coordinate is outside its valid geographic
    -- range, both coordinates are set to NULL.
    CASE
      WHEN d.longitude BETWEEN -180 AND 180
       AND d.latitude  BETWEEN -90  AND 90
      THEN d.longitude
      ELSE NULL
    END AS longitude,

    CASE
      WHEN d.longitude BETWEEN -180 AND 180
       AND d.latitude  BETWEEN -90  AND 90
      THEN d.latitude
      ELSE NULL
    END AS latitude,

    -- No validity filter is applied to accuracy.
    d.accuracy AS accuracy

  FROM gps_dedup AS d

  JOIN user_gps_unique_device AS u
    ON u.deviceId = d.deviceId

  WHERE d.cnt_min = 1;

END//


DELIMITER ;
