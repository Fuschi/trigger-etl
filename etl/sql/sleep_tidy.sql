-- ============================================================================
-- sleep_tidy.sql
--
-- Source tables (read only):
--   sleep(year, month, day, deviceId, firmware, created_at TIMESTAMP,
--         sleepduration, awake, insomnia, remsleep, lightsleep, deepsleep,
--         sleepquality, fallsleepefficiency)
--   user_sleep(deviceId, userId)
--
-- Managed objects:
--   sleep_tidy
--   etl_sleep_tidy()
--
-- Usage:
--   CALL etl_sleep_tidy();
--
-- An empty sleep_tidy triggers a full build. Otherwise the procedure finds raw
-- uploads whose created_at is greater than MAX(sleep_tidy.created_at) and
-- rebuilds their complete participant/reference-date keys.
-- ============================================================================


CREATE TABLE IF NOT EXISTS sleep_tidy (            -- Preserve a compatible existing table.
  userId    BIGINT       NOT NULL,                  -- Pseudonymous participant identifier.
  `date`    DATE         NOT NULL,                  -- Raw nightly reference date; start/end is unresolved.
  created_at DATETIME(6) NOT NULL,                  -- Selected final ingestion time, stored in UTC.
  deviceId  VARCHAR(128) NOT NULL,                  -- Source device retained as provenance.
  firmware  VARCHAR(128) NOT NULL,                  -- Source firmware retained as provenance.

  sleepduration SMALLINT UNSIGNED NOT NULL,         -- Total nightly duration in apparent minutes.
  awake         SMALLINT UNSIGNED NOT NULL,         -- Awake component in apparent minutes.
  insomnia      INT UNSIGNED          NULL,         -- Non-negative raw code/value; semantics unresolved.
  remsleep      SMALLINT UNSIGNED NOT NULL,         -- REM component in apparent minutes.
  lightsleep    SMALLINT UNSIGNED NOT NULL,         -- Light-sleep component in apparent minutes.
  deepsleep     SMALLINT UNSIGNED NOT NULL,         -- Deep-sleep component in apparent minutes.
  sleepquality  TINYINT UNSIGNED       NULL,         -- Raw ordinal quality code from 1 through 5.
  fallsleepefficiency INT UNSIGNED      NULL,         -- Non-negative raw value; unit unresolved.

  PRIMARY KEY (userId, `date`),                    -- Enforce one summary per participant/date.
  INDEX idx_sleep_tidy_date (`date`),              -- Cross-participant nightly queries.
  INDEX idx_sleep_tidy_created_at (created_at),    -- Incremental watermark lookup.

  CONSTRAINT chk_sleep_tidy_durations
    CHECK (                                        -- Require one physically bounded composition.
      sleepduration BETWEEN 1 AND 1440
      AND awake BETWEEN 0 AND 1440
      AND remsleep BETWEEN 0 AND 1440
      AND lightsleep BETWEEN 0 AND 1440
      AND deepsleep BETWEEN 0 AND 1440
      AND sleepduration = awake + remsleep + lightsleep + deepsleep
    ),
  CONSTRAINT chk_sleep_tidy_sleepquality
    CHECK (sleepquality IS NULL OR sleepquality BETWEEN 1 AND 5), -- Ordinal device code.
  CONSTRAINT chk_sleep_tidy_insomnia
    CHECK (insomnia IS NULL OR insomnia >= 0),      -- Do not invent a narrower semantic range.
  CONSTRAINT chk_sleep_tidy_fallsleepefficiency
    CHECK (fallsleepefficiency IS NULL OR fallsleepefficiency >= 0) -- Values above 100 are valid raw data.
) ENGINE = InnoDB;                                  -- Full and incremental replacements are transactional.


-- Use // so semicolons inside the procedure do not end CREATE PROCEDURE.
DELIMITER //


CREATE OR REPLACE PROCEDURE etl_sleep_tidy()       -- Replace the routine, not the output table.
SQL SECURITY INVOKER                               -- Use the privileges of the account running CALL.
MODIFIES SQL DATA                                  -- Declare that the procedure writes database data.
main: BEGIN                                        -- Open a named procedure block.
  DECLARE v_started_at DATETIME(6);                -- UTC procedure start time.
  DECLARE v_finished_at DATETIME(6);               -- UTC procedure finish time.
  DECLARE v_previous_created_at DATETIME(6) DEFAULT NULL; -- Current tidy ingestion watermark.
  DECLARE v_raw_max_created_at DATETIME(6) DEFAULT NULL;  -- Frozen raw cutoff for this run.
  DECLARE v_old_time_zone VARCHAR(64);             -- Session timezone to restore before returning.
  DECLARE v_is_full BOOLEAN DEFAULT FALSE;         -- TRUE only when sleep_tidy is empty.

  DECLARE v_affected_nights BIGINT UNSIGNED DEFAULT 0; -- Participant/date keys rebuilt by this run.
  DECLARE v_source_rows BIGINT UNSIGNED DEFAULT 0;     -- Raw rows represented by the selected scope.
  DECLARE v_deleted_rows BIGINT UNSIGNED DEFAULT 0;    -- Prior tidy rows removed before rebuilding.
  DECLARE v_inserted_rows BIGINT UNSIGNED DEFAULT 0;   -- Clean summaries inserted by this run.
  DECLARE v_total_rows BIGINT UNSIGNED DEFAULT 0;      -- Final sleep_tidy row count.

  DECLARE EXIT HANDLER FOR SQLEXCEPTION            -- Catch any SQL error raised below.
  BEGIN
    ROLLBACK;                                      -- Undo this run's complete delete and insert.

    IF v_old_time_zone IS NOT NULL THEN            -- Restore it only after it was saved.
      SET SESSION time_zone = v_old_time_zone;     -- Preserve the caller's later query behaviour.
    END IF;

    RESIGNAL;                                      -- Return the original error to the caller.
  END;

  SET v_old_time_zone = @@SESSION.time_zone;       -- Remember the caller's current timezone.
  -- sleep.created_at is expected to be TIMESTAMP; normalize reads to UTC.
  SET SESSION time_zone = '+00:00';                -- Make TIMESTAMP reads explicitly UTC.
  SET v_started_at = UTC_TIMESTAMP(6);             -- Record when this run started.

  SELECT MAX(t.created_at)
  INTO v_previous_created_at                       -- Store the current tidy watermark.
  FROM sleep_tidy AS t;                            -- NULL means that the tidy table is empty.

  SELECT MAX(s.created_at)
  INTO v_raw_max_created_at                        -- Freeze the raw upper cutoff for this run.
  FROM sleep AS s;                                 -- Later uploads wait for the next call.

  SET v_is_full = (v_previous_created_at IS NULL); -- Select full or incremental mode automatically.

  IF v_raw_max_created_at IS NULL THEN             -- An empty raw source is not a successful run.
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'sleep has no usable created_at watermark';
  END IF;

  DROP TEMPORARY TABLE IF EXISTS tmp_sleep_device_map; -- Clear this session's prior helper.
  CREATE TEMPORARY TABLE tmp_sleep_device_map (
    deviceId VARCHAR(100) NOT NULL,                -- Raw identifier used for source lookup.
    userId BIGINT NOT NULL,                        -- Unique participant assigned to the device.
    PRIMARY KEY (deviceId),                        -- Store one resolved mapping per device.
    INDEX idx_tmp_sleep_device_user (userId)       -- Find all devices assigned to one participant.
  ) ENGINE = InnoDB;

  INSERT INTO tmp_sleep_device_map (deviceId, userId)
  SELECT
    um.deviceId,
    MIN(um.userId) AS userId                       -- Safe because HAVING requires one user.
  FROM user_sleep AS um
  WHERE um.deviceId IS NOT NULL                    -- A missing device cannot be joined.
    AND TRIM(um.deviceId) <> ''                    -- Ignore blank identifiers.
    AND um.userId IS NOT NULL                      -- A missing participant is not a valid mapping.
  GROUP BY um.deviceId
  HAVING COUNT(DISTINCT um.userId) = 1;            -- Exclude devices assigned to several users.

  DROP TEMPORARY TABLE IF EXISTS tmp_sleep_source; -- Materialize this small nightly source once.
  CREATE TEMPORARY TABLE tmp_sleep_source (
    userId BIGINT NOT NULL,
    reference_date DATE NOT NULL,
    created_at DATETIME(6) NOT NULL,
    deviceId VARCHAR(128) NOT NULL,
    firmware VARCHAR(128) NOT NULL,
    sleepduration BIGINT NULL,
    awake BIGINT NULL,
    insomnia BIGINT NULL,
    remsleep BIGINT NULL,
    lightsleep BIGINT NULL,
    deepsleep BIGINT NULL,
    sleepquality BIGINT NULL,
    fallsleepefficiency BIGINT NULL,
    INDEX idx_tmp_sleep_source_user_date (userId, reference_date),
    INDEX idx_tmp_sleep_source_version (deviceId, firmware, reference_date, created_at)
  ) ENGINE = InnoDB;

  INSERT INTO tmp_sleep_source (                   -- Keep only technically addressable raw rows.
    userId,
    reference_date,
    created_at,
    deviceId,
    firmware,
    sleepduration,
    awake,
    insomnia,
    remsleep,
    lightsleep,
    deepsleep,
    sleepquality,
    fallsleepefficiency
  )
  SELECT
    dm.userId,
    d.reference_date,
    d.created_at,
    d.deviceId,
    d.firmware,
    d.sleepduration,
    d.awake,
    d.insomnia,
    d.remsleep,
    d.lightsleep,
    d.deepsleep,
    d.sleepquality,
    d.fallsleepefficiency
  FROM tmp_sleep_device_map AS dm
  INNER JOIN (
    SELECT
      s.*,
      CASE                                         -- Reject impossible calendar combinations.
        WHEN s.year BETWEEN 1000 AND 9999
         AND s.month BETWEEN 1 AND 12
         AND s.day BETWEEN 1 AND DAY(
           LAST_DAY(
             STR_TO_DATE(
               CONCAT(
                 LPAD(CAST(s.year AS CHAR), 4, '0'), '-',
                 LPAD(CAST(s.month AS CHAR), 2, '0'), '-01'
               ),
               '%Y-%m-%d'
             )
           )
         )
        THEN STR_TO_DATE(                          -- Construct the validated reference date.
          CONCAT(
            LPAD(CAST(s.year AS CHAR), 4, '0'), '-',
            LPAD(CAST(s.month AS CHAR), 2, '0'), '-',
            LPAD(CAST(s.day AS CHAR), 2, '0')
          ),
          '%Y-%m-%d'
        )
        ELSE NULL
      END AS reference_date
    FROM sleep AS s
    WHERE s.created_at <= v_raw_max_created_at     -- Stay inside this run's frozen cutoff.
  ) AS d
    ON d.deviceId = dm.deviceId                    -- Apply only unambiguous whole-device mappings.
  WHERE d.reference_date IS NOT NULL               -- An invalid calendar date cannot identify a night.
    AND d.firmware IS NOT NULL                     -- Firmware is part of the version key.
    AND TRIM(d.firmware) <> ''                     -- Exclude blank firmware identifiers.
    AND d.deviceId IS NOT NULL
    AND TRIM(d.deviceId) <> '';

  DROP TEMPORARY TABLE IF EXISTS tmp_sleep_nights; -- Hold participant/date keys selected for this run.
  CREATE TEMPORARY TABLE tmp_sleep_nights (
    userId BIGINT NOT NULL,
    reference_date DATE NOT NULL,
    PRIMARY KEY (userId, reference_date)           -- Rebuild each analytical key once.
  ) ENGINE = InnoDB;

  IF v_is_full THEN                                -- Full mode rebuilds every addressable night.
    INSERT INTO tmp_sleep_nights (userId, reference_date)
    SELECT DISTINCT
      s.userId,
      s.reference_date
    FROM tmp_sleep_source AS s;

    SELECT COUNT(*)
    INTO v_source_rows                             -- Report every raw row visible to the full run.
    FROM sleep AS s
    WHERE s.created_at <= v_raw_max_created_at
       OR s.created_at IS NULL;                    -- Missing ingestion time is visible but unusable.
  ELSE                                             -- Incremental mode starts from newer raw uploads.
    INSERT INTO tmp_sleep_nights (userId, reference_date)
    SELECT DISTINCT
      s.userId,
      s.reference_date
    FROM tmp_sleep_source AS s
    WHERE s.created_at > v_previous_created_at;    -- Strictly newer than the current tidy watermark.

    SELECT COUNT(*)
    INTO v_source_rows                             -- Count full raw history for affected keys.
    FROM tmp_sleep_source AS s
    INNER JOIN tmp_sleep_nights AS n
      ON n.userId = s.userId
     AND n.reference_date = s.reference_date;
  END IF;

  SELECT COUNT(*)
  INTO v_affected_nights                           -- Save the selected participant/date count.
  FROM tmp_sleep_nights;

  START TRANSACTION;                               -- Make each full or incremental replacement atomic.

  DELETE t
  FROM sleep_tidy AS t
  INNER JOIN tmp_sleep_nights AS n
    ON n.userId = t.userId
   AND n.reference_date = t.`date`;                -- Remove prior versions of affected nights.
  SET v_deleted_rows = ROW_COUNT();                -- Capture the deletion count immediately.

  INSERT INTO sleep_tidy (                         -- Map final values to explicit output columns.
    userId,
    `date`,
    created_at,
    deviceId,
    firmware,
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
  scoped_source AS (                               -- Step 1: read complete history for selected nights.
    SELECT s.*
    FROM tmp_sleep_source AS s
    INNER JOIN tmp_sleep_nights AS n
      ON n.userId = s.userId
     AND n.reference_date = s.reference_date
  ),

  version_marked AS (                              -- Step 2: mark the final visible device summary.
    SELECT
      s.*,
      MAX(s.created_at) OVER (
        PARTITION BY s.deviceId, s.firmware, s.reference_date
      ) AS final_created_at
    FROM scoped_source AS s
  ),

  final_copies AS (                                -- Step 3: retain only the greatest upload time.
    SELECT
      userId,
      reference_date,
      created_at,
      deviceId,
      firmware,
      sleepduration,
      awake,
      insomnia,
      remsleep,
      lightsleep,
      deepsleep,
      sleepquality,
      fallsleepefficiency
    FROM version_marked
    WHERE created_at = final_created_at
  ),

  equal_copies_collapsed AS (                      -- Step 4: collapse fully equal final copies.
    SELECT DISTINCT
      userId,
      reference_date,
      created_at,
      deviceId,
      firmware,
      sleepduration,
      awake,
      insomnia,
      remsleep,
      lightsleep,
      deepsleep,
      sleepquality,
      fallsleepefficiency
    FROM final_copies
  ),

  final_payload_checked AS (                       -- Step 5: detect equal-time conflicting payloads.
    SELECT
      s.*,
      COUNT(*) OVER (
        PARTITION BY s.deviceId, s.firmware, s.reference_date
      ) AS final_payload_n
    FROM equal_copies_collapsed AS s
  ),

  valid_summaries AS (                             -- Step 6: enforce the nightly duration identity.
    SELECT
      userId,
      reference_date,
      created_at,
      deviceId,
      firmware,
      sleepduration,
      awake,
      CASE WHEN insomnia >= 0 THEN insomnia ELSE NULL END AS insomnia,
      remsleep,
      lightsleep,
      deepsleep,
      CASE
        WHEN sleepquality BETWEEN 1 AND 5 THEN sleepquality
        ELSE NULL
      END AS sleepquality,
      CASE
        WHEN fallsleepefficiency >= 0 THEN fallsleepefficiency
        ELSE NULL
      END AS fallsleepefficiency
    FROM final_payload_checked
    WHERE final_payload_n = 1                      -- Never choose between conflicting final copies.
      AND sleepduration BETWEEN 1 AND 1440         -- A nightly total must fit within one day.
      AND awake BETWEEN 0 AND 1440                 -- Zero is a valid observed component.
      AND remsleep BETWEEN 0 AND 1440
      AND lightsleep BETWEEN 0 AND 1440
      AND deepsleep BETWEEN 0 AND 1440
      AND sleepduration = awake + remsleep + lightsleep + deepsleep
  ),

  participant_night_checked AS (                   -- Step 7: enforce participant/date uniqueness.
    SELECT
      s.*,
      COUNT(*) OVER (
        PARTITION BY s.userId, s.reference_date
      ) AS candidate_n                             -- Detect multiple devices or firmware versions.
    FROM valid_summaries AS s
  )

  SELECT
    userId,
    reference_date,
    created_at,
    deviceId,
    firmware,
    sleepduration,
    awake,
    insomnia,
    remsleep,
    lightsleep,
    deepsleep,
    sleepquality,
    fallsleepefficiency
  FROM participant_night_checked
  WHERE candidate_n = 1;                          -- Never select one simultaneous candidate arbitrarily.

  SET v_inserted_rows = ROW_COUNT();              -- Capture this run's inserted summaries.

  SELECT COUNT(*)
  INTO v_total_rows                               -- Validate the result before committing it.
  FROM sleep_tidy;

  IF v_is_full AND v_total_rows = 0 THEN          -- Never report an empty full build as successful.
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'sleep full build produced no tidy rows';
  END IF;

  COMMIT;                                         -- Make the complete successful replacement durable.

  SET v_finished_at = UTC_TIMESTAMP(6);           -- Record successful completion time.
  SET SESSION time_zone = v_old_time_zone;        -- Restore the caller's original timezone.

  SELECT
    IF(v_is_full, 'full', 'incremental') AS run_mode, -- Report the selected refresh mode.
    v_started_at AS started_at,                   -- UTC start of the procedure call.
    v_finished_at AS finished_at,                 -- UTC end of the successful procedure call.
    v_previous_created_at AS previous_created_at, -- Watermark found before this run.
    v_raw_max_created_at AS raw_max_created_at,   -- Raw upper cutoff used by this run.
    v_affected_nights AS affected_nights,         -- Participant/reference-date keys rebuilt.
    v_source_rows AS source_rows,                 -- Raw rows represented by that scope.
    v_deleted_rows AS deleted_tidy_rows,          -- Existing tidy rows removed by this run.
    v_inserted_rows AS inserted_tidy_rows,        -- Clean summaries inserted by this run.
    v_total_rows AS total_tidy_rows;              -- Return one non-persistent summary row.
END//


-- Restore the normal client delimiter for subsequent SQL statements.
DELIMITER ;
