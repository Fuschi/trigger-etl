-- =========================================================
-- etl_myair_5min.sql
--
-- Materialized five-minute aggregation of myair_tidy.
-- One row per device, firmware and fixed five-minute bucket.
--
-- Each bucket is represented by its starting timestamp:
--   10:00:00 <= event_ts < 10:05:00 -> 10:00:00
--   10:05:00 <= event_ts < 10:10:00 -> 10:05:00
--
-- For each measurement, the table stores:
--   mean  : arithmetic mean of the valid readings
--   min   : minimum valid reading
--   max   : maximum valid reading
--   raw_n : number of valid readings contributing to the bucket
--
-- A bucket is retained when at least one tidy record exists.
-- The number of raw readings is retained for data-quality
-- assessment, but must not be used as a weight when producing
-- hourly or daily temporal averages.
-- =========================================================


CREATE TABLE IF NOT EXISTS myair_5min (

  userId   BIGINT       NOT NULL,
  deviceId VARCHAR(128) NOT NULL,
  firmware VARCHAR(128) NOT NULL,

  bucket_5min DATETIME NOT NULL,
  date        DATE     NOT NULL,
  hour        TINYINT  NOT NULL,
  minute      TINYINT  NOT NULL,

  -- Total tidy records falling within the five-minute bucket
  records_n SMALLINT UNSIGNED NOT NULL,

  -- Particulate mass (µg/m³)
  pm1_mean  DOUBLE NULL,
  pm1_min   DOUBLE NULL,
  pm1_max   DOUBLE NULL,
  pm1_raw_n SMALLINT UNSIGNED NOT NULL,

  pm25_mean  DOUBLE NULL,
  pm25_min   DOUBLE NULL,
  pm25_max   DOUBLE NULL,
  pm25_raw_n SMALLINT UNSIGNED NOT NULL,

  pm10_mean  DOUBLE NULL,
  pm10_min   DOUBLE NULL,
  pm10_max   DOUBLE NULL,
  pm10_raw_n SMALLINT UNSIGNED NOT NULL,

  -- Particle counts (#/dL)
  pc03_mean  DOUBLE NULL,
  pc03_min   DOUBLE NULL,
  pc03_max   DOUBLE NULL,
  pc03_raw_n SMALLINT UNSIGNED NOT NULL,

  pc05_mean  DOUBLE NULL,
  pc05_min   DOUBLE NULL,
  pc05_max   DOUBLE NULL,
  pc05_raw_n SMALLINT UNSIGNED NOT NULL,

  pc1_mean  DOUBLE NULL,
  pc1_min   DOUBLE NULL,
  pc1_max   DOUBLE NULL,
  pc1_raw_n SMALLINT UNSIGNED NOT NULL,

  pc25_mean  DOUBLE NULL,
  pc25_min   DOUBLE NULL,
  pc25_max   DOUBLE NULL,
  pc25_raw_n SMALLINT UNSIGNED NOT NULL,

  pc5_mean  DOUBLE NULL,
  pc5_min   DOUBLE NULL,
  pc5_max   DOUBLE NULL,
  pc5_raw_n SMALLINT UNSIGNED NOT NULL,

  pc10_mean  DOUBLE NULL,
  pc10_min   DOUBLE NULL,
  pc10_max   DOUBLE NULL,
  pc10_raw_n SMALLINT UNSIGNED NOT NULL,

  -- Environmental measurements
  temperature_mean  DOUBLE NULL,
  temperature_min   DOUBLE NULL,
  temperature_max   DOUBLE NULL,
  temperature_raw_n SMALLINT UNSIGNED NOT NULL,

  humidity_mean  DOUBLE NULL,
  humidity_min   DOUBLE NULL,
  humidity_max   DOUBLE NULL,
  humidity_raw_n SMALLINT UNSIGNED NOT NULL,

  pressure_mean  DOUBLE NULL,
  pressure_min   DOUBLE NULL,
  pressure_max   DOUBLE NULL,
  pressure_raw_n SMALLINT UNSIGNED NOT NULL,

  sound_mean  DOUBLE NULL,
  sound_min   DOUBLE NULL,
  sound_max   DOUBLE NULL,
  sound_raw_n SMALLINT UNSIGNED NOT NULL,

  uvb_mean  DOUBLE NULL,
  uvb_min   DOUBLE NULL,
  uvb_max   DOUBLE NULL,
  uvb_raw_n SMALLINT UNSIGNED NOT NULL,

  light_mean  DOUBLE NULL,
  light_min   DOUBLE NULL,
  light_max   DOUBLE NULL,
  light_raw_n SMALLINT UNSIGNED NOT NULL,

  PRIMARY KEY (
    deviceId,
    firmware,
    bucket_5min
  ),

  INDEX idx_myair_5min_user_bucket5 (
    userId,
    bucket_5min
  ),

  INDEX idx_myair_5min_bucket5 (
    bucket_5min
  ),

  INDEX idx_myair_5min_date (
    date
  )

) ENGINE=InnoDB;


DELIMITER //


CREATE OR REPLACE PROCEDURE etl_myair_5min()
BEGIN

  -- Full rebuild of the materialized five-minute table
  DROP TABLE IF EXISTS myair_5min;

  CREATE TABLE myair_5min (

    userId   BIGINT       NOT NULL,
    deviceId VARCHAR(128) NOT NULL,
    firmware VARCHAR(128) NOT NULL,

    bucket_5min DATETIME NOT NULL,
    date        DATE     NOT NULL,
    hour        TINYINT  NOT NULL,
    minute      TINYINT  NOT NULL,

    records_n SMALLINT UNSIGNED NOT NULL,

    pm1_mean  DOUBLE NULL,
    pm1_min   DOUBLE NULL,
    pm1_max   DOUBLE NULL,
    pm1_raw_n SMALLINT UNSIGNED NOT NULL,

    pm25_mean  DOUBLE NULL,
    pm25_min   DOUBLE NULL,
    pm25_max   DOUBLE NULL,
    pm25_raw_n SMALLINT UNSIGNED NOT NULL,

    pm10_mean  DOUBLE NULL,
    pm10_min   DOUBLE NULL,
    pm10_max   DOUBLE NULL,
    pm10_raw_n SMALLINT UNSIGNED NOT NULL,

    pc03_mean  DOUBLE NULL,
    pc03_min   DOUBLE NULL,
    pc03_max   DOUBLE NULL,
    pc03_raw_n SMALLINT UNSIGNED NOT NULL,

    pc05_mean  DOUBLE NULL,
    pc05_min   DOUBLE NULL,
    pc05_max   DOUBLE NULL,
    pc05_raw_n SMALLINT UNSIGNED NOT NULL,

    pc1_mean  DOUBLE NULL,
    pc1_min   DOUBLE NULL,
    pc1_max   DOUBLE NULL,
    pc1_raw_n SMALLINT UNSIGNED NOT NULL,

    pc25_mean  DOUBLE NULL,
    pc25_min   DOUBLE NULL,
    pc25_max   DOUBLE NULL,
    pc25_raw_n SMALLINT UNSIGNED NOT NULL,

    pc5_mean  DOUBLE NULL,
    pc5_min   DOUBLE NULL,
    pc5_max   DOUBLE NULL,
    pc5_raw_n SMALLINT UNSIGNED NOT NULL,

    pc10_mean  DOUBLE NULL,
    pc10_min   DOUBLE NULL,
    pc10_max   DOUBLE NULL,
    pc10_raw_n SMALLINT UNSIGNED NOT NULL,

    temperature_mean  DOUBLE NULL,
    temperature_min   DOUBLE NULL,
    temperature_max   DOUBLE NULL,
    temperature_raw_n SMALLINT UNSIGNED NOT NULL,

    humidity_mean  DOUBLE NULL,
    humidity_min   DOUBLE NULL,
    humidity_max   DOUBLE NULL,
    humidity_raw_n SMALLINT UNSIGNED NOT NULL,

    pressure_mean  DOUBLE NULL,
    pressure_min   DOUBLE NULL,
    pressure_max   DOUBLE NULL,
    pressure_raw_n SMALLINT UNSIGNED NOT NULL,

    sound_mean  DOUBLE NULL,
    sound_min   DOUBLE NULL,
    sound_max   DOUBLE NULL,
    sound_raw_n SMALLINT UNSIGNED NOT NULL,

    uvb_mean  DOUBLE NULL,
    uvb_min   DOUBLE NULL,
    uvb_max   DOUBLE NULL,
    uvb_raw_n SMALLINT UNSIGNED NOT NULL,

    light_mean  DOUBLE NULL,
    light_min   DOUBLE NULL,
    light_max   DOUBLE NULL,
    light_raw_n SMALLINT UNSIGNED NOT NULL,

    PRIMARY KEY (
      deviceId,
      firmware,
      bucket_5min
    ),

    INDEX idx_myair_5min_user_bucket5 (
      userId,
      bucket_5min
    ),

    INDEX idx_myair_5min_bucket5 (
      bucket_5min
    ),

    INDEX idx_myair_5min_date (
      date
    )

  ) ENGINE=InnoDB;


  INSERT INTO myair_5min (
    userId,
    deviceId,
    firmware,

    bucket_5min,
    date,
    hour,
    minute,

    records_n,

    pm1_mean,
    pm1_min,
    pm1_max,
    pm1_raw_n,

    pm25_mean,
    pm25_min,
    pm25_max,
    pm25_raw_n,

    pm10_mean,
    pm10_min,
    pm10_max,
    pm10_raw_n,

    pc03_mean,
    pc03_min,
    pc03_max,
    pc03_raw_n,

    pc05_mean,
    pc05_min,
    pc05_max,
    pc05_raw_n,

    pc1_mean,
    pc1_min,
    pc1_max,
    pc1_raw_n,

    pc25_mean,
    pc25_min,
    pc25_max,
    pc25_raw_n,

    pc5_mean,
    pc5_min,
    pc5_max,
    pc5_raw_n,

    pc10_mean,
    pc10_min,
    pc10_max,
    pc10_raw_n,

    temperature_mean,
    temperature_min,
    temperature_max,
    temperature_raw_n,

    humidity_mean,
    humidity_min,
    humidity_max,
    humidity_raw_n,

    pressure_mean,
    pressure_min,
    pressure_max,
    pressure_raw_n,

    sound_mean,
    sound_min,
    sound_max,
    sound_raw_n,

    uvb_mean,
    uvb_min,
    uvb_max,
    uvb_raw_n,

    light_mean,
    light_min,
    light_max,
    light_raw_n
  )

  SELECT
    userId,
    deviceId,
    firmware,

    bucket_5min,
    DATE(bucket_5min)   AS date,
    HOUR(bucket_5min)   AS hour,
    MINUTE(bucket_5min) AS minute,

    COUNT(*) AS records_n,

    AVG(pm1)   AS pm1_mean,
    MIN(pm1)   AS pm1_min,
    MAX(pm1)   AS pm1_max,
    COUNT(pm1) AS pm1_raw_n,

    AVG(pm25)   AS pm25_mean,
    MIN(pm25)   AS pm25_min,
    MAX(pm25)   AS pm25_max,
    COUNT(pm25) AS pm25_raw_n,

    AVG(pm10)   AS pm10_mean,
    MIN(pm10)   AS pm10_min,
    MAX(pm10)   AS pm10_max,
    COUNT(pm10) AS pm10_raw_n,

    AVG(pc03)   AS pc03_mean,
    MIN(pc03)   AS pc03_min,
    MAX(pc03)   AS pc03_max,
    COUNT(pc03) AS pc03_raw_n,

    AVG(pc05)   AS pc05_mean,
    MIN(pc05)   AS pc05_min,
    MAX(pc05)   AS pc05_max,
    COUNT(pc05) AS pc05_raw_n,

    AVG(pc1)   AS pc1_mean,
    MIN(pc1)   AS pc1_min,
    MAX(pc1)   AS pc1_max,
    COUNT(pc1) AS pc1_raw_n,

    AVG(pc25)   AS pc25_mean,
    MIN(pc25)   AS pc25_min,
    MAX(pc25)   AS pc25_max,
    COUNT(pc25) AS pc25_raw_n,

    AVG(pc5)   AS pc5_mean,
    MIN(pc5)   AS pc5_min,
    MAX(pc5)   AS pc5_max,
    COUNT(pc5) AS pc5_raw_n,

    AVG(pc10)   AS pc10_mean,
    MIN(pc10)   AS pc10_min,
    MAX(pc10)   AS pc10_max,
    COUNT(pc10) AS pc10_raw_n,

    AVG(temperature)   AS temperature_mean,
    MIN(temperature)   AS temperature_min,
    MAX(temperature)   AS temperature_max,
    COUNT(temperature) AS temperature_raw_n,

    AVG(humidity)   AS humidity_mean,
    MIN(humidity)   AS humidity_min,
    MAX(humidity)   AS humidity_max,
    COUNT(humidity) AS humidity_raw_n,

    AVG(pressure)   AS pressure_mean,
    MIN(pressure)   AS pressure_min,
    MAX(pressure)   AS pressure_max,
    COUNT(pressure) AS pressure_raw_n,

    AVG(sound)   AS sound_mean,
    MIN(sound)   AS sound_min,
    MAX(sound)   AS sound_max,
    COUNT(sound) AS sound_raw_n,

    AVG(uvb)   AS uvb_mean,
    MIN(uvb)   AS uvb_min,
    MAX(uvb)   AS uvb_max,
    COUNT(uvb) AS uvb_raw_n,

    AVG(light)   AS light_mean,
    MIN(light)   AS light_min,
    MAX(light)   AS light_max,
    COUNT(light) AS light_raw_n

  FROM myair_tidy

  GROUP BY
    userId,
    deviceId,
    firmware,
    bucket_5min;

END//


DELIMITER ;
