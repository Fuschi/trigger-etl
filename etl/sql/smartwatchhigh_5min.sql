-- ============================================================================
-- smartwatchhigh_5min.sql
--
-- Source table (read only): smartwatchhigh_tidy
-- Managed objects: smartwatchhigh_5min, etl_smartwatchhigh_5min()
-- Usage: CALL etl_smartwatchhigh_5min();
--
-- Continuous measurements use mean/min/max/count. Categorical sleeprate uses
-- counts for raw codes 0 through 4 and is never averaged.
-- ============================================================================


CREATE TABLE IF NOT EXISTS smartwatchhigh_5min (  -- Preserve a compatible existing table.
  userId      BIGINT      NOT NULL,               -- Pseudonymous participant identifier.
  bucket_5min DATETIME(6) NOT NULL,               -- Beginning of the UTC five-minute interval.
  source_created_at_max DATETIME(6) NOT NULL,     -- Greatest tidy ingestion time represented.
  observed_minute_n TINYINT UNSIGNED NOT NULL,    -- Distinct observed minutes, from 1 through 5.

  device_n   TINYINT UNSIGNED NOT NULL,           -- Distinct devices represented.
  firmware_n TINYINT UNSIGNED NOT NULL,           -- Distinct firmware values represented.
  deviceId   VARCHAR(128) NULL,                   -- Present only when one device is represented.
  firmware   VARCHAR(128) NULL,                   -- Present only when one firmware is represented.

  heartrate_mean DOUBLE NULL, heartrate_min DOUBLE NULL, heartrate_max DOUBLE NULL,
  heartrate_n TINYINT UNSIGNED NOT NULL,          -- Valid heart-rate minutes in bpm.
  oxygens_mean DOUBLE NULL, oxygens_min DOUBLE NULL, oxygens_max DOUBLE NULL,
  oxygens_n TINYINT UNSIGNED NOT NULL,            -- Valid oxygen-saturation minutes in percent.
  breathrate_mean DOUBLE NULL, breathrate_min DOUBLE NULL, breathrate_max DOUBLE NULL,
  breathrate_n TINYINT UNSIGNED NOT NULL,         -- Valid breathing-rate minutes.

  sleeprate_n   TINYINT UNSIGNED NOT NULL,        -- All valid categorical sleep-state minutes.
  sleeprate_0_n TINYINT UNSIGNED NOT NULL,        -- Raw code counts; semantic labels unresolved.
  sleeprate_1_n TINYINT UNSIGNED NOT NULL,
  sleeprate_2_n TINYINT UNSIGNED NOT NULL,
  sleeprate_3_n TINYINT UNSIGNED NOT NULL,
  sleeprate_4_n TINYINT UNSIGNED NOT NULL,

  PRIMARY KEY (userId, bucket_5min),              -- Enforce one participant/bucket row.
  INDEX idx_smartwatchhigh_5min_bucket (bucket_5min),
  INDEX idx_smartwatchhigh_5min_source_created (source_created_at_max),

  CONSTRAINT chk_smartwatchhigh_5min_bucket_boundary
    CHECK (MOD(MINUTE(bucket_5min), 5) = 0
       AND SECOND(bucket_5min) = 0
       AND MICROSECOND(bucket_5min) = 0),          -- Enforce a fixed five-minute UTC boundary.
  CONSTRAINT chk_smartwatchhigh_5min_observed_minutes
    CHECK (observed_minute_n BETWEEN 1 AND 5),
  CONSTRAINT chk_smartwatchhigh_5min_provenance_counts
    CHECK (device_n BETWEEN 1 AND observed_minute_n
       AND firmware_n BETWEEN 1 AND observed_minute_n),
  CONSTRAINT chk_smartwatchhigh_5min_device_value
    CHECK ((device_n = 1 AND deviceId IS NOT NULL)
        OR (device_n > 1 AND deviceId IS NULL)),
  CONSTRAINT chk_smartwatchhigh_5min_firmware_value
    CHECK ((firmware_n = 1 AND firmware IS NOT NULL)
        OR (firmware_n > 1 AND firmware IS NULL)),
  CONSTRAINT chk_smartwatchhigh_5min_counts
    CHECK (
      heartrate_n BETWEEN 0 AND observed_minute_n
      AND oxygens_n BETWEEN 0 AND observed_minute_n
      AND breathrate_n BETWEEN 0 AND observed_minute_n
      AND sleeprate_n BETWEEN 0 AND observed_minute_n
      AND sleeprate_0_n + sleeprate_1_n + sleeprate_2_n
        + sleeprate_3_n + sleeprate_4_n = sleeprate_n
    ),
  CONSTRAINT chk_smartwatchhigh_5min_continuous_stats
    CHECK (
      ((heartrate_n = 0 AND heartrate_min IS NULL AND heartrate_mean IS NULL AND heartrate_max IS NULL)
       OR (heartrate_n > 0 AND heartrate_min IS NOT NULL AND heartrate_mean IS NOT NULL
        AND heartrate_max IS NOT NULL AND heartrate_min > 0
        AND heartrate_min <= heartrate_mean AND heartrate_mean <= heartrate_max))
      AND ((oxygens_n = 0 AND oxygens_min IS NULL AND oxygens_mean IS NULL AND oxygens_max IS NULL)
       OR (oxygens_n > 0 AND oxygens_min IS NOT NULL AND oxygens_mean IS NOT NULL
        AND oxygens_max IS NOT NULL AND oxygens_min BETWEEN 1 AND 100
        AND oxygens_min <= oxygens_mean AND oxygens_mean <= oxygens_max
        AND oxygens_max <= 100))
      AND ((breathrate_n = 0 AND breathrate_min IS NULL AND breathrate_mean IS NULL AND breathrate_max IS NULL)
       OR (breathrate_n > 0 AND breathrate_min IS NOT NULL AND breathrate_mean IS NOT NULL
        AND breathrate_max IS NOT NULL AND breathrate_min BETWEEN 1 AND 100
        AND breathrate_min <= breathrate_mean AND breathrate_mean <= breathrate_max
        AND breathrate_max <= 100))
    )
) ENGINE = InnoDB;


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_smartwatchhigh_5min()
SQL SECURITY INVOKER                              -- Execute with the caller's privileges.
MODIFIES SQL DATA                                 -- Replace data in the managed aggregate.
main: BEGIN
  DECLARE v_started_at DATETIME(6);
  DECLARE v_finished_at DATETIME(6);
  DECLARE v_source_rows BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_source_buckets BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_deleted_rows BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_inserted_rows BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_total_rows BIGINT UNSIGNED DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;                                     -- Restore the prior complete aggregate.
    RESIGNAL;
  END;

  SET v_started_at = UTC_TIMESTAMP(6);
  START TRANSACTION WITH CONSISTENT SNAPSHOT;      -- Use one stable tidy snapshot.

  SELECT COUNT(*) INTO v_source_rows FROM smartwatchhigh_tidy;

  IF v_source_rows = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'smartwatchhigh_tidy is empty; smartwatchhigh_5min was not rebuilt';
  END IF;

  SELECT COUNT(*)
  INTO v_source_buckets
  FROM (
    SELECT t.userId, t.bucket_5min
    FROM smartwatchhigh_tidy AS t
    GROUP BY t.userId, t.bucket_5min
  ) AS source_keys;

  DELETE FROM smartwatchhigh_5min;
  SET v_deleted_rows = ROW_COUNT();

  INSERT INTO smartwatchhigh_5min (
    userId, bucket_5min, source_created_at_max, observed_minute_n,
    device_n, firmware_n, deviceId, firmware,
    heartrate_mean, heartrate_min, heartrate_max, heartrate_n,
    oxygens_mean, oxygens_min, oxygens_max, oxygens_n,
    breathrate_mean, breathrate_min, breathrate_max, breathrate_n,
    sleeprate_n, sleeprate_0_n, sleeprate_1_n, sleeprate_2_n,
    sleeprate_3_n, sleeprate_4_n
  )
  SELECT
    t.userId,
    t.bucket_5min,
    MAX(t.created_at),
    COUNT(DISTINCT t.minute_ts),
    COUNT(DISTINCT t.deviceId),
    COUNT(DISTINCT t.firmware),
    CASE WHEN COUNT(DISTINCT t.deviceId) = 1 THEN MIN(t.deviceId) ELSE NULL END,
    CASE WHEN COUNT(DISTINCT t.firmware) = 1 THEN MIN(t.firmware) ELSE NULL END,
    AVG(t.heartrate), MIN(t.heartrate), MAX(t.heartrate), COUNT(t.heartrate),
    AVG(t.oxygens), MIN(t.oxygens), MAX(t.oxygens), COUNT(t.oxygens),
    AVG(t.breathrate), MIN(t.breathrate), MAX(t.breathrate), COUNT(t.breathrate),
    COUNT(t.sleeprate),
    SUM(CASE WHEN t.sleeprate = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN t.sleeprate = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN t.sleeprate = 2 THEN 1 ELSE 0 END),
    SUM(CASE WHEN t.sleeprate = 3 THEN 1 ELSE 0 END),
    SUM(CASE WHEN t.sleeprate = 4 THEN 1 ELSE 0 END)
  FROM smartwatchhigh_tidy AS t
  GROUP BY t.userId, t.bucket_5min;

  SET v_inserted_rows = ROW_COUNT();

  IF v_inserted_rows <> v_source_buckets THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'smartwatchhigh_5min output count differs from source bucket count';
  END IF;

  SELECT COUNT(*) INTO v_total_rows FROM smartwatchhigh_5min;

  IF v_total_rows <> v_source_buckets THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'smartwatchhigh_5min final count differs from source bucket count';
  END IF;

  COMMIT;
  SET v_finished_at = UTC_TIMESTAMP(6);

  SELECT
    'full' AS run_mode,
    v_started_at AS started_at,
    v_finished_at AS finished_at,
    v_source_rows AS source_rows,
    v_source_buckets AS source_buckets,
    v_deleted_rows AS deleted_5min_rows,
    v_inserted_rows AS inserted_5min_rows,
    v_total_rows AS total_5min_rows;
END//


DELIMITER ;
