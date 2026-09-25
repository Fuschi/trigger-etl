-- One paired GPS position per participant-minute.
-- Accuracy is copied unchanged: zero and negative values are retained; raw accuracy is NOT NULL.
-- Existing coordinate, provenance and ambiguity rules are unchanged.
-- Empty output: full build. Otherwise: rebuild participant-minutes touched by
-- newly ingested rows.

CREATE TABLE IF NOT EXISTS gps_tidy (
  userId      BIGINT       NOT NULL,
  minute_ts   DATETIME(6)  NOT NULL,
  bucket_5min DATETIME(6)  NOT NULL,
  event_ts    DATETIME(6)  NOT NULL,
  created_at  DATETIME(6)  NOT NULL,
  deviceId    VARCHAR(128) NOT NULL,
  firmware    VARCHAR(128) NOT NULL,
  longitude   DOUBLE       NOT NULL,
  latitude    DOUBLE       NOT NULL,
  accuracy    DOUBLE       NOT NULL,

  PRIMARY KEY (userId, minute_ts),
  INDEX idx_gps_tidy_user_bucket (userId, bucket_5min),
  INDEX idx_gps_tidy_bucket (bucket_5min),
  INDEX idx_gps_tidy_created_at (created_at),

  CONSTRAINT chk_gps_tidy_longitude
    CHECK (longitude BETWEEN -180 AND 180),
  CONSTRAINT chk_gps_tidy_latitude
    CHECK (latitude BETWEEN -90 AND 90)
) ENGINE = InnoDB;

DELIMITER //

CREATE OR REPLACE PROCEDURE etl_gps_tidy()
SQL SECURITY INVOKER
MODIFIES SQL DATA
main: BEGIN
  DECLARE v_started_at DATETIME(6);
  DECLARE v_finished_at DATETIME(6);
  DECLARE v_previous_created_at DATETIME(6) DEFAULT NULL;
  DECLARE v_raw_max_created_at DATETIME(6) DEFAULT NULL;
  DECLARE v_old_time_zone VARCHAR(64);
  DECLARE v_is_full BOOLEAN DEFAULT FALSE;

  DECLARE v_affected_days BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_source_rows BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_deleted_rows BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_inserted_rows BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_total_rows BIGINT UNSIGNED DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;

    IF v_old_time_zone IS NOT NULL THEN
      SET SESSION time_zone = v_old_time_zone;
    END IF;

    RESIGNAL;
  END;

  SET v_old_time_zone = @@SESSION.time_zone;

  SET SESSION time_zone = '+00:00';
  SET v_started_at = UTC_TIMESTAMP(6);

  START TRANSACTION;

  SELECT MAX(t.created_at)
  INTO v_previous_created_at
  FROM gps_tidy AS t;

  SELECT MAX(g.created_at)
  INTO v_raw_max_created_at
  FROM gps AS g;

  SET v_is_full = (v_previous_created_at IS NULL);

  DROP TEMPORARY TABLE IF EXISTS tmp_gps_device_map;
  CREATE TEMPORARY TABLE tmp_gps_device_map (
    deviceId VARCHAR(100) NOT NULL,
    userId BIGINT NOT NULL,
    PRIMARY KEY (deviceId),
    INDEX idx_tmp_gps_device_user (userId)
  ) ENGINE = InnoDB;

  INSERT INTO tmp_gps_device_map (deviceId, userId)
  SELECT
    ug.deviceId,
    MIN(ug.userId)
  FROM user_gps AS ug
  WHERE ug.deviceId IS NOT NULL
    AND TRIM(ug.deviceId) <> ''
    AND ug.userId IS NOT NULL
  GROUP BY ug.deviceId
  HAVING COUNT(DISTINCT ug.userId) = 1;

  DROP TEMPORARY TABLE IF EXISTS tmp_gps_minutes;
  CREATE TEMPORARY TABLE tmp_gps_minutes (
    userId BIGINT NOT NULL,
    minute_ts DATETIME(6) NOT NULL,
    PRIMARY KEY (userId, minute_ts)
  ) ENGINE = InnoDB;

  IF NOT v_is_full THEN
    INSERT INTO tmp_gps_minutes (userId, minute_ts)
    SELECT DISTINCT
      dm.userId,
      TIMESTAMP(
        DATE(g.event_ts),
        MAKETIME(HOUR(g.event_ts), MINUTE(g.event_ts), 0)
      )
    FROM tmp_gps_device_map AS dm
    INNER JOIN gps AS g
      ON g.deviceId = dm.deviceId
    WHERE g.firmware IS NOT NULL
      AND TRIM(g.firmware) <> ''
      AND g.event_ts IS NOT NULL
      AND g.created_at >= v_previous_created_at
      AND g.created_at <= v_raw_max_created_at;
  END IF;

  DROP TEMPORARY TABLE IF EXISTS tmp_gps_days;
  CREATE TEMPORARY TABLE tmp_gps_days (
    event_date DATE NOT NULL,
    PRIMARY KEY (event_date)
  ) ENGINE = InnoDB;

  IF v_is_full THEN
    INSERT INTO tmp_gps_days (event_date)
    SELECT DISTINCT DATE(g.event_ts)
    FROM gps AS g
    WHERE g.event_ts IS NOT NULL
      AND (g.created_at <= v_raw_max_created_at OR g.created_at IS NULL);
  ELSE
    INSERT INTO tmp_gps_days (event_date)
    SELECT DISTINCT DATE(m.minute_ts)
    FROM tmp_gps_minutes AS m;
  END IF;

  SELECT COUNT(*)
  INTO v_affected_days
  FROM tmp_gps_days;

  SELECT COUNT(*)
  INTO v_source_rows
  FROM gps AS g
  LEFT JOIN tmp_gps_device_map AS dm
    ON dm.deviceId = g.deviceId
  LEFT JOIN tmp_gps_minutes AS scope
    ON scope.userId = dm.userId
   AND scope.minute_ts = TIMESTAMP(
     DATE(g.event_ts),
     MAKETIME(HOUR(g.event_ts), MINUTE(g.event_ts), 0)
   )
  WHERE (v_is_full OR scope.userId IS NOT NULL)
    AND (g.created_at <= v_raw_max_created_at OR g.created_at IS NULL);

  IF v_is_full THEN

    DELETE FROM gps_tidy;
    SET v_deleted_rows = ROW_COUNT();
  ELSE
    DELETE t
    FROM gps_tidy AS t
    INNER JOIN tmp_gps_minutes AS m
      ON m.userId = t.userId
     AND m.minute_ts = t.minute_ts;
    SET v_deleted_rows = ROW_COUNT();
  END IF;

  INSERT INTO gps_tidy (
    userId,
    minute_ts,
    bucket_5min,
    event_ts,
    created_at,
    deviceId,
    firmware,
    longitude,
    latitude,
    accuracy
  )
  WITH
  required_rows AS (
    SELECT
      dm.userId,
      g.deviceId,
      g.firmware,
      g.event_ts,
      g.created_at,
      TIMESTAMP(
        DATE(g.event_ts),
        MAKETIME(HOUR(g.event_ts), MINUTE(g.event_ts), 0)
      ) AS minute_ts,
      g.longitude,
      g.latitude,
      g.accuracy,
      MIN(g.created_at) OVER (
        PARTITION BY g.deviceId, g.firmware, g.event_ts
      ) AS first_created_at
    FROM tmp_gps_device_map AS dm
    INNER JOIN gps AS g
      ON g.deviceId = dm.deviceId
    LEFT JOIN tmp_gps_minutes AS scope
      ON scope.userId = dm.userId
     AND scope.minute_ts = TIMESTAMP(
       DATE(g.event_ts),
       MAKETIME(HOUR(g.event_ts), MINUTE(g.event_ts), 0)
     )
    WHERE (v_is_full OR scope.userId IS NOT NULL)
      AND g.firmware IS NOT NULL
      AND TRIM(g.firmware) <> ''
      AND g.event_ts IS NOT NULL
      AND g.created_at IS NOT NULL
      AND g.created_at <= v_raw_max_created_at
  ),

  earliest_payloads AS (
    SELECT
      userId,
      deviceId,
      firmware,
      event_ts,
      created_at,
      minute_ts,
      longitude,
      latitude,
      accuracy
    FROM required_rows
    WHERE created_at = first_created_at
    GROUP BY
      userId,
      deviceId,
      firmware,
      event_ts,
      created_at,
      minute_ts,
      longitude,
      latitude,
      accuracy
  ),

  event_checked AS (
    SELECT
      p.*,
      COUNT(*) OVER (
        PARTITION BY p.deviceId, p.firmware, p.event_ts
      ) AS payload_n
    FROM earliest_payloads AS p
  ),

  device_minute_checked AS (
    SELECT
      e.*,
      COUNT(*) OVER (
        PARTITION BY e.deviceId, e.firmware, e.minute_ts
      ) AS event_n
    FROM event_checked AS e
    WHERE e.payload_n = 1
  ),

  valid_positions AS (
    SELECT
      userId,
      deviceId,
      firmware,
      event_ts,
      created_at,
      minute_ts,
      longitude,
      latitude,
      accuracy
    FROM device_minute_checked
    WHERE event_n = 1
      AND longitude BETWEEN -180 AND 180
      AND latitude BETWEEN -90 AND 90
  ),

  participant_minute_checked AS (
    SELECT
      p.*,
      COUNT(*) OVER (
        PARTITION BY p.userId, p.minute_ts
      ) AS candidate_n
    FROM valid_positions AS p
  )

  SELECT
    userId,
    minute_ts,
    minute_ts - INTERVAL (MINUTE(minute_ts) MOD 5) MINUTE,
    event_ts,
    created_at,
    deviceId,
    firmware,
    longitude,
    latitude,
    accuracy
  FROM participant_minute_checked
  WHERE candidate_n = 1;

  SET v_inserted_rows = ROW_COUNT();

  SELECT COUNT(*)
  INTO v_total_rows
  FROM gps_tidy;

  IF v_total_rows = 0 THEN                       -- Reject empty output in either refresh mode.
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'gps refresh produced no tidy rows';
  END IF;

  COMMIT;

  SET v_finished_at = UTC_TIMESTAMP(6);
  SET SESSION time_zone = v_old_time_zone;

  SELECT
    IF(v_is_full, 'full', 'incremental') AS run_mode,
    v_started_at AS started_at,
    v_finished_at AS finished_at,
    v_previous_created_at AS previous_created_at,
    v_raw_max_created_at AS raw_max_created_at,
    v_affected_days AS affected_days,
    v_source_rows AS source_rows,
    v_deleted_rows AS deleted_tidy_rows,
    v_inserted_rows AS inserted_tidy_rows,
    v_total_rows AS total_tidy_rows;

END//

DELIMITER ;
