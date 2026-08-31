-- ============================================================================
-- myair_5min.sql
--
-- Source table (read only): myair_tidy
-- Managed objects: myair_5min, etl_myair_5min()
-- Usage: CALL etl_myair_5min();
--
-- This canonical implementation performs one transactional full rebuild.
-- A full rebuild remains correct when a tidy correction removes a prior row;
-- a watermark over only the currently present tidy rows cannot detect that.
-- ============================================================================


CREATE TABLE IF NOT EXISTS myair_5min (            -- Preserve a compatible existing table.
  userId      BIGINT      NOT NULL,                -- Pseudonymous participant identifier.
  bucket_5min DATETIME(6) NOT NULL,                -- Beginning of the UTC five-minute interval.
  source_created_at_max DATETIME(6) NOT NULL,      -- Greatest tidy ingestion time represented.
  observed_minute_n TINYINT UNSIGNED NOT NULL,     -- Distinct observed minutes, from 1 through 5.

  device_n   TINYINT UNSIGNED NOT NULL,            -- Distinct devices represented in the bucket.
  firmware_n TINYINT UNSIGNED NOT NULL,            -- Distinct firmware values represented.
  deviceId   VARCHAR(128) NULL,                    -- Present only for one represented device.
  firmware   VARCHAR(128) NULL,                    -- Present only for one represented firmware.

  pm1_mean DOUBLE NULL, pm1_min DOUBLE NULL, pm1_max DOUBLE NULL,
  pm1_n TINYINT UNSIGNED NOT NULL,                 -- Valid particulate-mass minutes.
  pm25_mean DOUBLE NULL, pm25_min DOUBLE NULL, pm25_max DOUBLE NULL,
  pm25_n TINYINT UNSIGNED NOT NULL,
  pm10_mean DOUBLE NULL, pm10_min DOUBLE NULL, pm10_max DOUBLE NULL,
  pm10_n TINYINT UNSIGNED NOT NULL,

  pc03_mean DOUBLE NULL, pc03_min DOUBLE NULL, pc03_max DOUBLE NULL,
  pc03_n TINYINT UNSIGNED NOT NULL,                -- Valid particle-count minutes.
  pc05_mean DOUBLE NULL, pc05_min DOUBLE NULL, pc05_max DOUBLE NULL,
  pc05_n TINYINT UNSIGNED NOT NULL,
  pc1_mean DOUBLE NULL, pc1_min DOUBLE NULL, pc1_max DOUBLE NULL,
  pc1_n TINYINT UNSIGNED NOT NULL,
  pc25_mean DOUBLE NULL, pc25_min DOUBLE NULL, pc25_max DOUBLE NULL,
  pc25_n TINYINT UNSIGNED NOT NULL,
  pc5_mean DOUBLE NULL, pc5_min DOUBLE NULL, pc5_max DOUBLE NULL,
  pc5_n TINYINT UNSIGNED NOT NULL,
  pc10_mean DOUBLE NULL, pc10_min DOUBLE NULL, pc10_max DOUBLE NULL,
  pc10_n TINYINT UNSIGNED NOT NULL,

  temperature_mean DOUBLE NULL, temperature_min DOUBLE NULL, temperature_max DOUBLE NULL,
  temperature_n TINYINT UNSIGNED NOT NULL,         -- Valid recorded-temperature minutes.
  humidity_mean DOUBLE NULL, humidity_min DOUBLE NULL, humidity_max DOUBLE NULL,
  humidity_n TINYINT UNSIGNED NOT NULL,
  pressure_mean DOUBLE NULL, pressure_min DOUBLE NULL, pressure_max DOUBLE NULL,
  pressure_n TINYINT UNSIGNED NOT NULL,
  sound_mean DOUBLE NULL, sound_min DOUBLE NULL, sound_max DOUBLE NULL,
  sound_n TINYINT UNSIGNED NOT NULL,
  uvb_mean DOUBLE NULL, uvb_min DOUBLE NULL, uvb_max DOUBLE NULL,
  uvb_n TINYINT UNSIGNED NOT NULL,
  light_mean DOUBLE NULL, light_min DOUBLE NULL, light_max DOUBLE NULL,
  light_n TINYINT UNSIGNED NOT NULL,

  PRIMARY KEY (userId, bucket_5min),               -- Enforce one participant/bucket row.
  INDEX idx_myair_5min_bucket (bucket_5min),       -- Shared-time joins and coverage queries.
  INDEX idx_myair_5min_source_created (source_created_at_max), -- Freshness inspection.

  CONSTRAINT chk_myair_5min_bucket_boundary
    CHECK (MOD(MINUTE(bucket_5min), 5) = 0
       AND SECOND(bucket_5min) = 0
       AND MICROSECOND(bucket_5min) = 0),          -- Enforce a fixed five-minute UTC boundary.
  CONSTRAINT chk_myair_5min_observed_minutes
    CHECK (observed_minute_n BETWEEN 1 AND 5),
  CONSTRAINT chk_myair_5min_provenance_counts
    CHECK (device_n BETWEEN 1 AND observed_minute_n
       AND firmware_n BETWEEN 1 AND observed_minute_n),
  CONSTRAINT chk_myair_5min_device_value
    CHECK ((device_n = 1 AND deviceId IS NOT NULL)
        OR (device_n > 1 AND deviceId IS NULL)),
  CONSTRAINT chk_myair_5min_firmware_value
    CHECK ((firmware_n = 1 AND firmware IS NOT NULL)
        OR (firmware_n > 1 AND firmware IS NULL)),
  CONSTRAINT chk_myair_5min_counts
    CHECK (                                        -- No measurement can outnumber observed minutes.
      pm1_n BETWEEN 0 AND observed_minute_n
      AND pm25_n BETWEEN 0 AND observed_minute_n
      AND pm10_n BETWEEN 0 AND observed_minute_n
      AND pc03_n BETWEEN 0 AND observed_minute_n
      AND pc05_n BETWEEN 0 AND observed_minute_n
      AND pc1_n BETWEEN 0 AND observed_minute_n
      AND pc25_n BETWEEN 0 AND observed_minute_n
      AND pc5_n BETWEEN 0 AND observed_minute_n
      AND pc10_n BETWEEN 0 AND observed_minute_n
      AND temperature_n BETWEEN 0 AND observed_minute_n
      AND humidity_n BETWEEN 0 AND observed_minute_n
      AND pressure_n BETWEEN 0 AND observed_minute_n
      AND sound_n BETWEEN 0 AND observed_minute_n
      AND uvb_n BETWEEN 0 AND observed_minute_n
      AND light_n BETWEEN 0 AND observed_minute_n
    ),
  CONSTRAINT chk_myair_5min_pm_stats
    CHECK (
      ((pm1_n = 0 AND pm1_min IS NULL AND pm1_mean IS NULL AND pm1_max IS NULL)
       OR (pm1_n > 0 AND pm1_min IS NOT NULL AND pm1_mean IS NOT NULL AND pm1_max IS NOT NULL
        AND pm1_min <= pm1_mean AND pm1_mean <= pm1_max))
      AND ((pm25_n = 0 AND pm25_min IS NULL AND pm25_mean IS NULL AND pm25_max IS NULL)
       OR (pm25_n > 0 AND pm25_min IS NOT NULL AND pm25_mean IS NOT NULL AND pm25_max IS NOT NULL
        AND pm25_min <= pm25_mean AND pm25_mean <= pm25_max))
      AND ((pm10_n = 0 AND pm10_min IS NULL AND pm10_mean IS NULL AND pm10_max IS NULL)
       OR (pm10_n > 0 AND pm10_min IS NOT NULL AND pm10_mean IS NOT NULL AND pm10_max IS NOT NULL
        AND pm10_min <= pm10_mean AND pm10_mean <= pm10_max))
    ),
  CONSTRAINT chk_myair_5min_pc_stats
    CHECK (
      ((pc03_n = 0 AND pc03_min IS NULL AND pc03_mean IS NULL AND pc03_max IS NULL)
       OR (pc03_n > 0 AND pc03_min IS NOT NULL AND pc03_mean IS NOT NULL AND pc03_max IS NOT NULL
        AND pc03_min <= pc03_mean AND pc03_mean <= pc03_max))
      AND ((pc05_n = 0 AND pc05_min IS NULL AND pc05_mean IS NULL AND pc05_max IS NULL)
       OR (pc05_n > 0 AND pc05_min IS NOT NULL AND pc05_mean IS NOT NULL AND pc05_max IS NOT NULL
        AND pc05_min <= pc05_mean AND pc05_mean <= pc05_max))
      AND ((pc1_n = 0 AND pc1_min IS NULL AND pc1_mean IS NULL AND pc1_max IS NULL)
       OR (pc1_n > 0 AND pc1_min IS NOT NULL AND pc1_mean IS NOT NULL AND pc1_max IS NOT NULL
        AND pc1_min <= pc1_mean AND pc1_mean <= pc1_max))
      AND ((pc25_n = 0 AND pc25_min IS NULL AND pc25_mean IS NULL AND pc25_max IS NULL)
       OR (pc25_n > 0 AND pc25_min IS NOT NULL AND pc25_mean IS NOT NULL AND pc25_max IS NOT NULL
        AND pc25_min <= pc25_mean AND pc25_mean <= pc25_max))
      AND ((pc5_n = 0 AND pc5_min IS NULL AND pc5_mean IS NULL AND pc5_max IS NULL)
       OR (pc5_n > 0 AND pc5_min IS NOT NULL AND pc5_mean IS NOT NULL AND pc5_max IS NOT NULL
        AND pc5_min <= pc5_mean AND pc5_mean <= pc5_max))
      AND ((pc10_n = 0 AND pc10_min IS NULL AND pc10_mean IS NULL AND pc10_max IS NULL)
       OR (pc10_n > 0 AND pc10_min IS NOT NULL AND pc10_mean IS NOT NULL AND pc10_max IS NOT NULL
        AND pc10_min <= pc10_mean AND pc10_mean <= pc10_max))
    ),
  CONSTRAINT chk_myair_5min_environment_stats
    CHECK (
      ((temperature_n = 0 AND temperature_min IS NULL AND temperature_mean IS NULL AND temperature_max IS NULL)
       OR (temperature_n > 0 AND temperature_min IS NOT NULL AND temperature_mean IS NOT NULL
        AND temperature_max IS NOT NULL AND temperature_min <= temperature_mean
        AND temperature_mean <= temperature_max))
      AND ((humidity_n = 0 AND humidity_min IS NULL AND humidity_mean IS NULL AND humidity_max IS NULL)
       OR (humidity_n > 0 AND humidity_min IS NOT NULL AND humidity_mean IS NOT NULL
        AND humidity_max IS NOT NULL AND humidity_min <= humidity_mean AND humidity_mean <= humidity_max))
      AND ((pressure_n = 0 AND pressure_min IS NULL AND pressure_mean IS NULL AND pressure_max IS NULL)
       OR (pressure_n > 0 AND pressure_min IS NOT NULL AND pressure_mean IS NOT NULL
        AND pressure_max IS NOT NULL AND pressure_min <= pressure_mean AND pressure_mean <= pressure_max))
      AND ((sound_n = 0 AND sound_min IS NULL AND sound_mean IS NULL AND sound_max IS NULL)
       OR (sound_n > 0 AND sound_min IS NOT NULL AND sound_mean IS NOT NULL AND sound_max IS NOT NULL
        AND sound_min <= sound_mean AND sound_mean <= sound_max))
      AND ((uvb_n = 0 AND uvb_min IS NULL AND uvb_mean IS NULL AND uvb_max IS NULL)
       OR (uvb_n > 0 AND uvb_min IS NOT NULL AND uvb_mean IS NOT NULL AND uvb_max IS NOT NULL
        AND uvb_min <= uvb_mean AND uvb_mean <= uvb_max))
      AND ((light_n = 0 AND light_min IS NULL AND light_mean IS NULL AND light_max IS NULL)
       OR (light_n > 0 AND light_min IS NOT NULL AND light_mean IS NOT NULL AND light_max IS NOT NULL
        AND light_min <= light_mean AND light_mean <= light_max))
    )
) ENGINE = InnoDB;                                 -- Replace the aggregate transactionally.


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_myair_5min()      -- Replace the routine, not the output table.
SQL SECURITY INVOKER                              -- Execute with the caller's privileges.
MODIFIES SQL DATA                                 -- This procedure replaces managed data.
main: BEGIN
  DECLARE v_started_at DATETIME(6);               -- UTC procedure start time.
  DECLARE v_finished_at DATETIME(6);              -- UTC procedure finish time.
  DECLARE v_source_rows BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_source_buckets BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_deleted_rows BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_inserted_rows BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_total_rows BIGINT UNSIGNED DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;                                     -- Preserve the prior complete aggregate on error.
    RESIGNAL;
  END;

  SET v_started_at = UTC_TIMESTAMP(6);
  START TRANSACTION WITH CONSISTENT SNAPSHOT;      -- Use one stable tidy snapshot.

  SELECT COUNT(*) INTO v_source_rows FROM myair_tidy;

  IF v_source_rows = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'myair_tidy is empty; myair_5min was not rebuilt';
  END IF;

  SELECT COUNT(*)
  INTO v_source_buckets
  FROM (
    SELECT t.userId, t.bucket_5min
    FROM myair_tidy AS t
    GROUP BY t.userId, t.bucket_5min
  ) AS source_keys;

  DELETE FROM myair_5min;                         -- Keep the reviewed definition and indexes.
  SET v_deleted_rows = ROW_COUNT();

  INSERT INTO myair_5min (
    userId, bucket_5min, source_created_at_max, observed_minute_n,
    device_n, firmware_n, deviceId, firmware,
    pm1_mean, pm1_min, pm1_max, pm1_n,
    pm25_mean, pm25_min, pm25_max, pm25_n,
    pm10_mean, pm10_min, pm10_max, pm10_n,
    pc03_mean, pc03_min, pc03_max, pc03_n,
    pc05_mean, pc05_min, pc05_max, pc05_n,
    pc1_mean, pc1_min, pc1_max, pc1_n,
    pc25_mean, pc25_min, pc25_max, pc25_n,
    pc5_mean, pc5_min, pc5_max, pc5_n,
    pc10_mean, pc10_min, pc10_max, pc10_n,
    temperature_mean, temperature_min, temperature_max, temperature_n,
    humidity_mean, humidity_min, humidity_max, humidity_n,
    pressure_mean, pressure_min, pressure_max, pressure_n,
    sound_mean, sound_min, sound_max, sound_n,
    uvb_mean, uvb_min, uvb_max, uvb_n,
    light_mean, light_min, light_max, light_n
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

    AVG(t.pm1), MIN(t.pm1), MAX(t.pm1), COUNT(t.pm1),
    AVG(t.pm25), MIN(t.pm25), MAX(t.pm25), COUNT(t.pm25),
    AVG(t.pm10), MIN(t.pm10), MAX(t.pm10), COUNT(t.pm10),
    AVG(t.pc03), MIN(t.pc03), MAX(t.pc03), COUNT(t.pc03),
    AVG(t.pc05), MIN(t.pc05), MAX(t.pc05), COUNT(t.pc05),
    AVG(t.pc1), MIN(t.pc1), MAX(t.pc1), COUNT(t.pc1),
    AVG(t.pc25), MIN(t.pc25), MAX(t.pc25), COUNT(t.pc25),
    AVG(t.pc5), MIN(t.pc5), MAX(t.pc5), COUNT(t.pc5),
    AVG(t.pc10), MIN(t.pc10), MAX(t.pc10), COUNT(t.pc10),
    AVG(t.temperature), MIN(t.temperature), MAX(t.temperature), COUNT(t.temperature),
    AVG(t.humidity), MIN(t.humidity), MAX(t.humidity), COUNT(t.humidity),
    AVG(t.pressure), MIN(t.pressure), MAX(t.pressure), COUNT(t.pressure),
    AVG(t.sound), MIN(t.sound), MAX(t.sound), COUNT(t.sound),
    AVG(t.uvb), MIN(t.uvb), MAX(t.uvb), COUNT(t.uvb),
    AVG(t.light), MIN(t.light), MAX(t.light), COUNT(t.light)
  FROM myair_tidy AS t
  GROUP BY t.userId, t.bucket_5min;

  SET v_inserted_rows = ROW_COUNT();

  IF v_inserted_rows <> v_source_buckets THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'myair_5min output count differs from source bucket count';
  END IF;

  SELECT COUNT(*) INTO v_total_rows FROM myair_5min;

  IF v_total_rows <> v_source_buckets THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'myair_5min final count differs from source bucket count';
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
