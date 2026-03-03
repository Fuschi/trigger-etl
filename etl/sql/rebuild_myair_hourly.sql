-- =========================================================
-- myair_hourly full rebuild (IN-PLACE)
-- - strict second-level de-duplication (drop ambiguous seconds)
-- - keep only deviceIds mapping to exactly one userId
-- - rebuild in place: TRUNCATE + INSERT (no swap tables)
-- =========================================================

CREATE TABLE IF NOT EXISTS myair_hourly (
  userId   BIGINT       NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  firmware VARCHAR(128) NOT NULL,
  date     DATE         NOT NULL,
  hour     TINYINT      NOT NULL,

  -- Particulate mass
  pm1_mean  DOUBLE NULL, pm1_min  DOUBLE NULL, pm1_max  DOUBLE NULL, pm1_valid_n  INT NOT NULL,
  pm25_mean DOUBLE NULL, pm25_min DOUBLE NULL, pm25_max DOUBLE NULL, pm25_valid_n INT NOT NULL,
  pm10_mean DOUBLE NULL, pm10_min DOUBLE NULL, pm10_max DOUBLE NULL, pm10_valid_n INT NOT NULL,

  -- Particle counts
  pc03_mean DOUBLE NULL, pc03_min DOUBLE NULL, pc03_max DOUBLE NULL, pc03_valid_n INT NOT NULL,
  pc05_mean DOUBLE NULL, pc05_min DOUBLE NULL, pc05_max DOUBLE NULL, pc05_valid_n INT NOT NULL,
  pc1_mean  DOUBLE NULL, pc1_min  DOUBLE NULL, pc1_max  DOUBLE NULL, pc1_valid_n  INT NOT NULL,
  pc25_mean DOUBLE NULL, pc25_min DOUBLE NULL, pc25_max DOUBLE NULL, pc25_valid_n INT NOT NULL,
  pc5_mean  DOUBLE NULL, pc5_min  DOUBLE NULL, pc5_max  DOUBLE NULL, pc5_valid_n  INT NOT NULL,
  pc10_mean DOUBLE NULL, pc10_min DOUBLE NULL, pc10_max DOUBLE NULL, pc10_valid_n INT NOT NULL,

  -- Environmental variables
  temperature_mean DOUBLE NULL, temperature_min DOUBLE NULL, temperature_max DOUBLE NULL, temperature_valid_n INT NOT NULL,
  humidity_mean    DOUBLE NULL, humidity_min    DOUBLE NULL, humidity_max    DOUBLE NULL, humidity_valid_n    INT NOT NULL,
  pressure_mean    DOUBLE NULL, pressure_min    DOUBLE NULL, pressure_max    DOUBLE NULL, pressure_valid_n    INT NOT NULL,
  sound_mean       DOUBLE NULL, sound_min       DOUBLE NULL, sound_max       DOUBLE NULL, sound_valid_n       INT NOT NULL,
  uvb_mean         DOUBLE NULL, uvb_min         DOUBLE NULL, uvb_max         DOUBLE NULL, uvb_valid_n         INT NOT NULL,
  light_mean       DOUBLE NULL, light_min       DOUBLE NULL, light_max       DOUBLE NULL, light_valid_n       INT NOT NULL,

  -- Total number of rows contributing to the hourly record (after strict dedup + user binding)
  myair_records_n  INT NOT NULL,

  PRIMARY KEY (userId, deviceId, firmware, date, hour),
  INDEX idx_myair_hourly_date_hour (date, hour),
  INDEX idx_myair_hourly_device (deviceId),
  INDEX idx_myair_hourly_user (userId)
) ENGINE=InnoDB;

DELIMITER //

CREATE OR REPLACE PROCEDURE rebuild_myair_hourly()
BEGIN
  /*
    NOTE:
    This rebuild is "in place". During the rebuild window the hourly table
    will be empty (after TRUNCATE) and then progressively refilled.
  */

  TRUNCATE TABLE myair_hourly;

  INSERT INTO myair_hourly (
    userId, deviceId, firmware, date, hour,

    pm1_mean, pm1_min, pm1_max, pm1_valid_n,
    pm25_mean, pm25_min, pm25_max, pm25_valid_n,
    pm10_mean, pm10_min, pm10_max, pm10_valid_n,

    pc03_mean, pc03_min, pc03_max, pc03_valid_n,
    pc05_mean, pc05_min, pc05_max, pc05_valid_n,
    pc1_mean,  pc1_min,  pc1_max,  pc1_valid_n,
    pc25_mean, pc25_min, pc25_max, pc25_valid_n,
    pc5_mean,  pc5_min,  pc5_max,  pc5_valid_n,
    pc10_mean, pc10_min, pc10_max, pc10_valid_n,

    temperature_mean, temperature_min, temperature_max, temperature_valid_n,
    humidity_mean,    humidity_min,    humidity_max,    humidity_valid_n,
    pressure_mean,    pressure_min,    pressure_max,    pressure_valid_n,
    sound_mean,       sound_min,       sound_max,       sound_valid_n,
    uvb_mean,         uvb_min,         uvb_max,         uvb_valid_n,
    light_mean,       light_min,       light_max,       light_valid_n,

    myair_records_n
  )
  WITH
  second_bucket_min_created_at AS (
    SELECT deviceId, firmware, event_ts, MIN(created_at) AS min_created_at
    FROM myair
    GROUP BY deviceId, firmware, event_ts
  ),
  second_bucket_created_at_counts AS (
    SELECT deviceId, firmware, event_ts, created_at, COUNT(*) AS cnt_at_created
    FROM myair
    GROUP BY deviceId, firmware, event_ts, created_at
  ),
  second_bucket_unique_minimum AS (
    SELECT m.deviceId, m.firmware, m.event_ts, m.min_created_at
    FROM second_bucket_min_created_at AS m
    JOIN second_bucket_created_at_counts AS c
      ON  c.deviceId = m.deviceId
      AND c.firmware = m.firmware
      AND c.event_ts = m.event_ts
      AND c.created_at = m.min_created_at
    WHERE c.cnt_at_created = 1
  ),
  myair_strict_second_dedup AS (
    SELECT y.*
    FROM myair AS y
    JOIN second_bucket_unique_minimum AS u
      ON  y.deviceId = u.deviceId
      AND y.firmware = u.firmware
      AND y.event_ts = u.event_ts
      AND y.created_at = u.min_created_at
  ),
  user_myair_unique_device AS (
    SELECT deviceId, MIN(userId) AS userId
    FROM user_myair
    GROUP BY deviceId
    HAVING COUNT(DISTINCT userId) = 1
  ),
  myair_strict_second_dedup_with_user AS (
    SELECT d.*, u.userId
    FROM myair_strict_second_dedup AS d
    JOIN user_myair_unique_device AS u
      ON u.deviceId = d.deviceId
  )
  SELECT
    d.userId,
    d.deviceId,
    d.firmware,
    DATE(d.event_ts) AS date,
    HOUR(d.event_ts) AS hour,

    -- Particulate mass (>= 0 valid)
    CAST(AVG(CASE WHEN d.pm1  >= 0 THEN d.pm1  END) AS DOUBLE) AS pm1_mean,
    CAST(MIN(CASE WHEN d.pm1  >= 0 THEN d.pm1  END) AS DOUBLE) AS pm1_min,
    CAST(MAX(CASE WHEN d.pm1  >= 0 THEN d.pm1  END) AS DOUBLE) AS pm1_max,
    SUM(CASE WHEN d.pm1  >= 0 THEN 1 ELSE 0 END) AS pm1_valid_n,

    CAST(AVG(CASE WHEN d.pm25 >= 0 THEN d.pm25 END) AS DOUBLE) AS pm25_mean,
    CAST(MIN(CASE WHEN d.pm25 >= 0 THEN d.pm25 END) AS DOUBLE) AS pm25_min,
    CAST(MAX(CASE WHEN d.pm25 >= 0 THEN d.pm25 END) AS DOUBLE) AS pm25_max,
    SUM(CASE WHEN d.pm25 >= 0 THEN 1 ELSE 0 END) AS pm25_valid_n,

    CAST(AVG(CASE WHEN d.pm10 >= 0 THEN d.pm10 END) AS DOUBLE) AS pm10_mean,
    CAST(MIN(CASE WHEN d.pm10 >= 0 THEN d.pm10 END) AS DOUBLE) AS pm10_min,
    CAST(MAX(CASE WHEN d.pm10 >= 0 THEN d.pm10 END) AS DOUBLE) AS pm10_max,
    SUM(CASE WHEN d.pm10 >= 0 THEN 1 ELSE 0 END) AS pm10_valid_n,

    -- Particle counts (>= 0 valid)
    CAST(AVG(CASE WHEN d.pc03 >= 0 THEN d.pc03 END) AS DOUBLE) AS pc03_mean,
    CAST(MIN(CASE WHEN d.pc03 >= 0 THEN d.pc03 END) AS DOUBLE) AS pc03_min,
    CAST(MAX(CASE WHEN d.pc03 >= 0 THEN d.pc03 END) AS DOUBLE) AS pc03_max,
    SUM(CASE WHEN d.pc03 >= 0 THEN 1 ELSE 0 END) AS pc03_valid_n,

    CAST(AVG(CASE WHEN d.pc05 >= 0 THEN d.pc05 END) AS DOUBLE) AS pc05_mean,
    CAST(MIN(CASE WHEN d.pc05 >= 0 THEN d.pc05 END) AS DOUBLE) AS pc05_min,
    CAST(MAX(CASE WHEN d.pc05 >= 0 THEN d.pc05 END) AS DOUBLE) AS pc05_max,
    SUM(CASE WHEN d.pc05 >= 0 THEN 1 ELSE 0 END) AS pc05_valid_n,

    CAST(AVG(CASE WHEN d.pc1  >= 0 THEN d.pc1  END) AS DOUBLE) AS pc1_mean,
    CAST(MIN(CASE WHEN d.pc1  >= 0 THEN d.pc1  END) AS DOUBLE) AS pc1_min,
    CAST(MAX(CASE WHEN d.pc1  >= 0 THEN d.pc1  END) AS DOUBLE) AS pc1_max,
    SUM(CASE WHEN d.pc1  >= 0 THEN 1 ELSE 0 END) AS pc1_valid_n,

    CAST(AVG(CASE WHEN d.pc25 >= 0 THEN d.pc25 END) AS DOUBLE) AS pc25_mean,
    CAST(MIN(CASE WHEN d.pc25 >= 0 THEN d.pc25 END) AS DOUBLE) AS pc25_min,
    CAST(MAX(CASE WHEN d.pc25 >= 0 THEN d.pc25 END) AS DOUBLE) AS pc25_max,
    SUM(CASE WHEN d.pc25 >= 0 THEN 1 ELSE 0 END) AS pc25_valid_n,

    CAST(AVG(CASE WHEN d.pc5  >= 0 THEN d.pc5  END) AS DOUBLE) AS pc5_mean,
    CAST(MIN(CASE WHEN d.pc5  >= 0 THEN d.pc5  END) AS DOUBLE) AS pc5_min,
    CAST(MAX(CASE WHEN d.pc5  >= 0 THEN d.pc5  END) AS DOUBLE) AS pc5_max,
    SUM(CASE WHEN d.pc5  >= 0 THEN 1 ELSE 0 END) AS pc5_valid_n,

    CAST(AVG(CASE WHEN d.pc10 >= 0 THEN d.pc10 END) AS DOUBLE) AS pc10_mean,
    CAST(MIN(CASE WHEN d.pc10 >= 0 THEN d.pc10 END) AS DOUBLE) AS pc10_min,
    CAST(MAX(CASE WHEN d.pc10 >= 0 THEN d.pc10 END) AS DOUBLE) AS pc10_max,
    SUM(CASE WHEN d.pc10 >= 0 THEN 1 ELSE 0 END) AS pc10_valid_n,

    -- Environmental variables (IS NOT NULL valid)
    CAST(AVG(CASE WHEN d.temperature IS NOT NULL THEN d.temperature END) AS DOUBLE) AS temperature_mean,
    CAST(MIN(CASE WHEN d.temperature IS NOT NULL THEN d.temperature END) AS DOUBLE) AS temperature_min,
    CAST(MAX(CASE WHEN d.temperature IS NOT NULL THEN d.temperature END) AS DOUBLE) AS temperature_max,
    SUM(CASE WHEN d.temperature IS NOT NULL THEN 1 ELSE 0 END) AS temperature_valid_n,

    CAST(AVG(CASE WHEN d.humidity IS NOT NULL THEN d.humidity END) AS DOUBLE) AS humidity_mean,
    CAST(MIN(CASE WHEN d.humidity IS NOT NULL THEN d.humidity END) AS DOUBLE) AS humidity_min,
    CAST(MAX(CASE WHEN d.humidity IS NOT NULL THEN d.humidity END) AS DOUBLE) AS humidity_max,
    SUM(CASE WHEN d.humidity IS NOT NULL THEN 1 ELSE 0 END) AS humidity_valid_n,

    CAST(AVG(CASE WHEN d.pressure IS NOT NULL THEN d.pressure END) AS DOUBLE) AS pressure_mean,
    CAST(MIN(CASE WHEN d.pressure IS NOT NULL THEN d.pressure END) AS DOUBLE) AS pressure_min,
    CAST(MAX(CASE WHEN d.pressure IS NOT NULL THEN d.pressure END) AS DOUBLE) AS pressure_max,
    SUM(CASE WHEN d.pressure IS NOT NULL THEN 1 ELSE 0 END) AS pressure_valid_n,

    CAST(AVG(CASE WHEN d.sound IS NOT NULL THEN d.sound END) AS DOUBLE) AS sound_mean,
    CAST(MIN(CASE WHEN d.sound IS NOT NULL THEN d.sound END) AS DOUBLE) AS sound_min,
    CAST(MAX(CASE WHEN d.sound IS NOT NULL THEN d.sound END) AS DOUBLE) AS sound_max,
    SUM(CASE WHEN d.sound IS NOT NULL THEN 1 ELSE 0 END) AS sound_valid_n,

    CAST(AVG(CASE WHEN d.uvb IS NOT NULL THEN d.uvb END) AS DOUBLE) AS uvb_mean,
    CAST(MIN(CASE WHEN d.uvb IS NOT NULL THEN d.uvb END) AS DOUBLE) AS uvb_min,
    CAST(MAX(CASE WHEN d.uvb IS NOT NULL THEN d.uvb END) AS DOUBLE) AS uvb_max,
    SUM(CASE WHEN d.uvb IS NOT NULL THEN 1 ELSE 0 END) AS uvb_valid_n,

    CAST(AVG(CASE WHEN d.light IS NOT NULL THEN d.light END) AS DOUBLE) AS light_mean,
    CAST(MIN(CASE WHEN d.light IS NOT NULL THEN d.light END) AS DOUBLE) AS light_min,
    CAST(MAX(CASE WHEN d.light IS NOT NULL THEN d.light END) AS DOUBLE) AS light_max,
    SUM(CASE WHEN d.light IS NOT NULL THEN 1 ELSE 0 END) AS light_valid_n,

    -- Total rows after strict dedup + user binding
    COUNT(*) AS myair_records_n

  FROM myair_strict_second_dedup_with_user AS d
  GROUP BY d.userId, d.deviceId, d.firmware, DATE(d.event_ts), HOUR(d.event_ts);

END//

DELIMITER ;

