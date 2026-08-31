-- ============================================================================
-- smartwatchlow_5min.sql
--
-- Source table (read only): smartwatchlow_tidy
-- Managed objects: smartwatchlow_5min, etl_smartwatchlow_5min()
-- Usage: CALL etl_smartwatchlow_5min();
--
-- The canonical definition performs a deletion-aware full rebuild.
-- ============================================================================


CREATE TABLE IF NOT EXISTS smartwatchlow_5min (   -- Preserve a compatible existing table.
  userId      BIGINT      NOT NULL,               -- Pseudonymous participant identifier.
  bucket_5min DATETIME(6) NOT NULL,               -- Beginning of the UTC five-minute interval.
  source_created_at_max DATETIME(6) NOT NULL,     -- Greatest tidy ingestion time represented.
  observed_minute_n TINYINT UNSIGNED NOT NULL,    -- Distinct observed minutes, from 1 through 5.

  device_n   TINYINT UNSIGNED NOT NULL,           -- Distinct devices represented.
  firmware_n TINYINT UNSIGNED NOT NULL,           -- Distinct firmware values represented.
  deviceId   VARCHAR(128) NULL,                   -- Present only when one device is represented.
  firmware   VARCHAR(128) NULL,                   -- Present only when one firmware is represented.

  step_mean DOUBLE NULL, step_min DOUBLE NULL, step_max DOUBLE NULL,
  step_n TINYINT UNSIGNED NOT NULL,               -- Five-minute interval value; minute copies are not summed.
  cal_mean DOUBLE NULL, cal_min DOUBLE NULL, cal_max DOUBLE NULL,
  cal_n TINYINT UNSIGNED NOT NULL,                -- Recorded calorie value; exact unit unresolved.
  bphigh_mean DOUBLE NULL, bphigh_min DOUBLE NULL, bphigh_max DOUBLE NULL,
  bphigh_n TINYINT UNSIGNED NOT NULL,             -- Higher member of the pressure pair, presumed mmHg.
  bplow_mean DOUBLE NULL, bplow_min DOUBLE NULL, bplow_max DOUBLE NULL,
  bplow_n TINYINT UNSIGNED NOT NULL,              -- Lower member of the pressure pair, presumed mmHg.
  bodytemp_mean DOUBLE NULL, bodytemp_min DOUBLE NULL, bodytemp_max DOUBLE NULL,
  bodytemp_n TINYINT UNSIGNED NOT NULL,           -- Minutes with a recorded raw bodytemp value.
  skintemp_mean DOUBLE NULL, skintemp_min DOUBLE NULL, skintemp_max DOUBLE NULL,
  skintemp_n TINYINT UNSIGNED NOT NULL,           -- Minutes with a recorded raw skintemp value.

  PRIMARY KEY (userId, bucket_5min),              -- Enforce one participant/bucket row.
  INDEX idx_smartwatchlow_5min_bucket (bucket_5min),
  INDEX idx_smartwatchlow_5min_source_created (source_created_at_max),

  CONSTRAINT chk_smartwatchlow_5min_bucket_boundary
    CHECK (MOD(MINUTE(bucket_5min), 5) = 0
       AND SECOND(bucket_5min) = 0
       AND MICROSECOND(bucket_5min) = 0),          -- Enforce a fixed five-minute UTC boundary.
  CONSTRAINT chk_smartwatchlow_5min_observed_minutes
    CHECK (observed_minute_n BETWEEN 1 AND 5),
  CONSTRAINT chk_smartwatchlow_5min_provenance_counts
    CHECK (device_n BETWEEN 1 AND observed_minute_n
       AND firmware_n BETWEEN 1 AND observed_minute_n),
  CONSTRAINT chk_smartwatchlow_5min_device_value
    CHECK ((device_n = 1 AND deviceId IS NOT NULL)
        OR (device_n > 1 AND deviceId IS NULL)),
  CONSTRAINT chk_smartwatchlow_5min_firmware_value
    CHECK ((firmware_n = 1 AND firmware IS NOT NULL)
        OR (firmware_n > 1 AND firmware IS NULL)),
  CONSTRAINT chk_smartwatchlow_5min_counts
    CHECK (
      step_n BETWEEN 0 AND observed_minute_n
      AND cal_n BETWEEN 0 AND observed_minute_n
      AND bphigh_n BETWEEN 0 AND observed_minute_n
      AND bplow_n = bphigh_n                      -- Pressure availability remains paired.
      AND bodytemp_n BETWEEN 0 AND observed_minute_n
      AND skintemp_n BETWEEN 0 AND observed_minute_n
    ),
  CONSTRAINT chk_smartwatchlow_5min_activity_stats
    CHECK (
      ((step_n = 0 AND step_min IS NULL AND step_mean IS NULL AND step_max IS NULL)
       OR (step_n > 0 AND step_min IS NOT NULL AND step_mean IS NOT NULL AND step_max IS NOT NULL
        AND step_min >= 0 AND step_min <= step_mean AND step_mean <= step_max))
      AND ((cal_n = 0 AND cal_min IS NULL AND cal_mean IS NULL AND cal_max IS NULL)
       OR (cal_n > 0 AND cal_min IS NOT NULL AND cal_mean IS NOT NULL AND cal_max IS NOT NULL
        AND cal_min >= 0 AND cal_min <= cal_mean AND cal_mean <= cal_max))
    ),
  CONSTRAINT chk_smartwatchlow_5min_pressure_stats
    CHECK (
      ((bphigh_n = 0
        AND bphigh_min IS NULL AND bphigh_mean IS NULL AND bphigh_max IS NULL
        AND bplow_min IS NULL AND bplow_mean IS NULL AND bplow_max IS NULL)
       OR (bphigh_n > 0
        AND bphigh_min IS NOT NULL AND bphigh_mean IS NOT NULL AND bphigh_max IS NOT NULL
        AND bplow_min IS NOT NULL AND bplow_mean IS NOT NULL AND bplow_max IS NOT NULL
        AND bphigh_min <= bphigh_mean AND bphigh_mean <= bphigh_max
        AND bplow_min <= bplow_mean AND bplow_mean <= bplow_max
        AND bphigh_mean >= bplow_mean))
    ),
  CONSTRAINT chk_smartwatchlow_5min_temperature_stats
    CHECK (
      ((bodytemp_n = 0 AND bodytemp_min IS NULL AND bodytemp_mean IS NULL AND bodytemp_max IS NULL)
       OR (bodytemp_n > 0 AND bodytemp_min IS NOT NULL AND bodytemp_mean IS NOT NULL
        AND bodytemp_max IS NOT NULL AND bodytemp_min <= bodytemp_mean
        AND bodytemp_mean <= bodytemp_max))
      AND ((skintemp_n = 0 AND skintemp_min IS NULL AND skintemp_mean IS NULL AND skintemp_max IS NULL)
       OR (skintemp_n > 0 AND skintemp_min IS NOT NULL AND skintemp_mean IS NOT NULL
        AND skintemp_max IS NOT NULL AND skintemp_min <= skintemp_mean
        AND skintemp_mean <= skintemp_max))
    )
) ENGINE = InnoDB;


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_smartwatchlow_5min()
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
    ROLLBACK;                                     -- Restore the previous complete aggregate.
    RESIGNAL;
  END;

  SET v_started_at = UTC_TIMESTAMP(6);
  START TRANSACTION WITH CONSISTENT SNAPSHOT;      -- Read one stable tidy version.

  SELECT COUNT(*) INTO v_source_rows FROM smartwatchlow_tidy;

  IF v_source_rows = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'smartwatchlow_tidy is empty; smartwatchlow_5min was not rebuilt';
  END IF;

  SELECT COUNT(*)
  INTO v_source_buckets
  FROM (
    SELECT t.userId, t.bucket_5min
    FROM smartwatchlow_tidy AS t
    GROUP BY t.userId, t.bucket_5min
  ) AS source_keys;

  DELETE FROM smartwatchlow_5min;
  SET v_deleted_rows = ROW_COUNT();

  INSERT INTO smartwatchlow_5min (
    userId, bucket_5min, source_created_at_max, observed_minute_n,
    device_n, firmware_n, deviceId, firmware,
    step_mean, step_min, step_max, step_n,
    cal_mean, cal_min, cal_max, cal_n,
    bphigh_mean, bphigh_min, bphigh_max, bphigh_n,
    bplow_mean, bplow_min, bplow_max, bplow_n,
    bodytemp_mean, bodytemp_min, bodytemp_max, bodytemp_n,
    skintemp_mean, skintemp_min, skintemp_max, skintemp_n
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
    AVG(t.step), MIN(t.step), MAX(t.step), COUNT(t.step),
    AVG(t.cal), MIN(t.cal), MAX(t.cal), COUNT(t.cal),
    AVG(t.bphigh), MIN(t.bphigh), MAX(t.bphigh), COUNT(t.bphigh),
    AVG(t.bplow), MIN(t.bplow), MAX(t.bplow), COUNT(t.bplow),
    AVG(t.bodytemp), MIN(t.bodytemp), MAX(t.bodytemp), COUNT(t.bodytemp),
    AVG(t.skintemp), MIN(t.skintemp), MAX(t.skintemp), COUNT(t.skintemp)
  FROM smartwatchlow_tidy AS t
  GROUP BY t.userId, t.bucket_5min;

  SET v_inserted_rows = ROW_COUNT();

  IF v_inserted_rows <> v_source_buckets THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'smartwatchlow_5min output count differs from source bucket count';
  END IF;

  SELECT COUNT(*) INTO v_total_rows FROM smartwatchlow_5min;

  IF v_total_rows <> v_source_buckets THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'smartwatchlow_5min final count differs from source bucket count';
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
