DELIMITER //

CREATE OR REPLACE PROCEDURE sp_myair_daily(
  IN min_valid_default INT,

  IN date_from DATE,         -- NULL = no lower bound
  IN date_to   DATE,         -- NULL = no upper bound
  IN userId    BIGINT,       -- NULL = all
  IN deviceId  VARCHAR(128), -- NULL = all

  /* Optional per-metric thresholds (NULL = use min_valid_default) */
  IN min_valid_pm1  INT,
  IN min_valid_pm25 INT,
  IN min_valid_pm10 INT,

  IN min_valid_pc03 INT,
  IN min_valid_pc05 INT,
  IN min_valid_pc1  INT,
  IN min_valid_pc25 INT,
  IN min_valid_pc5  INT,
  IN min_valid_pc10 INT,

  IN min_valid_temperature INT,
  IN min_valid_humidity    INT,
  IN min_valid_pressure    INT,
  IN min_valid_sound       INT,
  IN min_valid_uvb         INT,
  IN min_valid_light       INT
)
BEGIN
  /*
    myair_hourly -> daily aggregation (no persistence, returns a result set)

    Rule (per metric X):
      - Include an hour only if X_valid_n > threshold(X)
      - threshold(X) = COALESCE(min_valid_X, min_valid_default)

    Outputs (per metric X):
      - X_mean / X_min / X_max computed only over included hours
      - X_valid_n = SUM(X_valid_n) over included hours
      - X_hours_n = number of included hours

    Extra:
      - records_n = SUM(myair_records_n) across all hours (regardless of thresholds)
  */

  SELECT
    h.userId,
    h.deviceId,
    h.firmware,
    h.date,

    /* -------------------------
       PM (validity: pm*_valid_n)
    ------------------------- */

    /* PM1 */
    AVG(CASE WHEN h.pm1_valid_n  > COALESCE(min_valid_pm1,  min_valid_default) THEN h.pm1_mean END) AS pm1_mean,
    MIN(CASE WHEN h.pm1_valid_n  > COALESCE(min_valid_pm1,  min_valid_default) THEN h.pm1_min  END) AS pm1_min,
    MAX(CASE WHEN h.pm1_valid_n  > COALESCE(min_valid_pm1,  min_valid_default) THEN h.pm1_max  END) AS pm1_max,
    SUM(CASE WHEN h.pm1_valid_n  > COALESCE(min_valid_pm1,  min_valid_default) THEN h.pm1_valid_n ELSE 0 END) AS pm1_valid_n,
    SUM(CASE WHEN h.pm1_valid_n  > COALESCE(min_valid_pm1,  min_valid_default) THEN 1 ELSE 0 END) AS pm1_hours_n,

    /* PM2.5 */
    AVG(CASE WHEN h.pm25_valid_n > COALESCE(min_valid_pm25, min_valid_default) THEN h.pm25_mean END) AS pm25_mean,
    MIN(CASE WHEN h.pm25_valid_n > COALESCE(min_valid_pm25, min_valid_default) THEN h.pm25_min  END) AS pm25_min,
    MAX(CASE WHEN h.pm25_valid_n > COALESCE(min_valid_pm25, min_valid_default) THEN h.pm25_max  END) AS pm25_max,
    SUM(CASE WHEN h.pm25_valid_n > COALESCE(min_valid_pm25, min_valid_default) THEN h.pm25_valid_n ELSE 0 END) AS pm25_valid_n,
    SUM(CASE WHEN h.pm25_valid_n > COALESCE(min_valid_pm25, min_valid_default) THEN 1 ELSE 0 END) AS pm25_hours_n,

    /* PM10 */
    AVG(CASE WHEN h.pm10_valid_n > COALESCE(min_valid_pm10, min_valid_default) THEN h.pm10_mean END) AS pm10_mean,
    MIN(CASE WHEN h.pm10_valid_n > COALESCE(min_valid_pm10, min_valid_default) THEN h.pm10_min  END) AS pm10_min,
    MAX(CASE WHEN h.pm10_valid_n > COALESCE(min_valid_pm10, min_valid_default) THEN h.pm10_max  END) AS pm10_max,
    SUM(CASE WHEN h.pm10_valid_n > COALESCE(min_valid_pm10, min_valid_default) THEN h.pm10_valid_n ELSE 0 END) AS pm10_valid_n,
    SUM(CASE WHEN h.pm10_valid_n > COALESCE(min_valid_pm10, min_valid_default) THEN 1 ELSE 0 END) AS pm10_hours_n,

    /* -------------------------
       Particle counts (validity: pc*_valid_n)
    ------------------------- */

    /* PC0.3 */
    AVG(CASE WHEN h.pc03_valid_n > COALESCE(min_valid_pc03, min_valid_default) THEN h.pc03_mean END) AS pc03_mean,
    MIN(CASE WHEN h.pc03_valid_n > COALESCE(min_valid_pc03, min_valid_default) THEN h.pc03_min  END) AS pc03_min,
    MAX(CASE WHEN h.pc03_valid_n > COALESCE(min_valid_pc03, min_valid_default) THEN h.pc03_max  END) AS pc03_max,
    SUM(CASE WHEN h.pc03_valid_n > COALESCE(min_valid_pc03, min_valid_default) THEN h.pc03_valid_n ELSE 0 END) AS pc03_valid_n,
    SUM(CASE WHEN h.pc03_valid_n > COALESCE(min_valid_pc03, min_valid_default) THEN 1 ELSE 0 END) AS pc03_hours_n,

    /* PC0.5 */
    AVG(CASE WHEN h.pc05_valid_n > COALESCE(min_valid_pc05, min_valid_default) THEN h.pc05_mean END) AS pc05_mean,
    MIN(CASE WHEN h.pc05_valid_n > COALESCE(min_valid_pc05, min_valid_default) THEN h.pc05_min  END) AS pc05_min,
    MAX(CASE WHEN h.pc05_valid_n > COALESCE(min_valid_pc05, min_valid_default) THEN h.pc05_max  END) AS pc05_max,
    SUM(CASE WHEN h.pc05_valid_n > COALESCE(min_valid_pc05, min_valid_default) THEN h.pc05_valid_n ELSE 0 END) AS pc05_valid_n,
    SUM(CASE WHEN h.pc05_valid_n > COALESCE(min_valid_pc05, min_valid_default) THEN 1 ELSE 0 END) AS pc05_hours_n,

    /* PC1 */
    AVG(CASE WHEN h.pc1_valid_n  > COALESCE(min_valid_pc1,  min_valid_default) THEN h.pc1_mean END) AS pc1_mean,
    MIN(CASE WHEN h.pc1_valid_n  > COALESCE(min_valid_pc1,  min_valid_default) THEN h.pc1_min  END) AS pc1_min,
    MAX(CASE WHEN h.pc1_valid_n  > COALESCE(min_valid_pc1,  min_valid_default) THEN h.pc1_max END) AS pc1_max,
    SUM(CASE WHEN h.pc1_valid_n  > COALESCE(min_valid_pc1,  min_valid_default) THEN h.pc1_valid_n ELSE 0 END) AS pc1_valid_n,
    SUM(CASE WHEN h.pc1_valid_n  > COALESCE(min_valid_pc1,  min_valid_default) THEN 1 ELSE 0 END) AS pc1_hours_n,

    /* PC2.5 */
    AVG(CASE WHEN h.pc25_valid_n > COALESCE(min_valid_pc25, min_valid_default) THEN h.pc25_mean END) AS pc25_mean,
    MIN(CASE WHEN h.pc25_valid_n > COALESCE(min_valid_pc25, min_valid_default) THEN h.pc25_min  END) AS pc25_min,
    MAX(CASE WHEN h.pc25_valid_n > COALESCE(min_valid_pc25, min_valid_default) THEN h.pc25_max  END) AS pc25_max,
    SUM(CASE WHEN h.pc25_valid_n > COALESCE(min_valid_pc25, min_valid_default) THEN h.pc25_valid_n ELSE 0 END) AS pc25_valid_n,
    SUM(CASE WHEN h.pc25_valid_n > COALESCE(min_valid_pc25, min_valid_default) THEN 1 ELSE 0 END) AS pc25_hours_n,

    /* PC5 */
    AVG(CASE WHEN h.pc5_valid_n  > COALESCE(min_valid_pc5,  min_valid_default) THEN h.pc5_mean END) AS pc5_mean,
    MIN(CASE WHEN h.pc5_valid_n  > COALESCE(min_valid_pc5,  min_valid_default) THEN h.pc5_min  END) AS pc5_min,
    MAX(CASE WHEN h.pc5_valid_n  > COALESCE(min_valid_pc5,  min_valid_default) THEN h.pc5_max  END) AS pc5_max,
    SUM(CASE WHEN h.pc5_valid_n  > COALESCE(min_valid_pc5,  min_valid_default) THEN h.pc5_valid_n ELSE 0 END) AS pc5_valid_n,
    SUM(CASE WHEN h.pc5_valid_n  > COALESCE(min_valid_pc5,  min_valid_default) THEN 1 ELSE 0 END) AS pc5_hours_n,

    /* PC10 */
    AVG(CASE WHEN h.pc10_valid_n > COALESCE(min_valid_pc10, min_valid_default) THEN h.pc10_mean END) AS pc10_mean,
    MIN(CASE WHEN h.pc10_valid_n > COALESCE(min_valid_pc10, min_valid_default) THEN h.pc10_min  END) AS pc10_min,
    MAX(CASE WHEN h.pc10_valid_n > COALESCE(min_valid_pc10, min_valid_default) THEN h.pc10_max  END) AS pc10_max,
    SUM(CASE WHEN h.pc10_valid_n > COALESCE(min_valid_pc10, min_valid_default) THEN h.pc10_valid_n ELSE 0 END) AS pc10_valid_n,
    SUM(CASE WHEN h.pc10_valid_n > COALESCE(min_valid_pc10, min_valid_default) THEN 1 ELSE 0 END) AS pc10_hours_n,

    /* -------------------------
       Environmental sensors (validity: *_valid_n)
    ------------------------- */

    /* Temperature */
    AVG(CASE WHEN h.temperature_valid_n > COALESCE(min_valid_temperature, min_valid_default) THEN h.temperature_mean END) AS temperature_mean,
    MIN(CASE WHEN h.temperature_valid_n > COALESCE(min_valid_temperature, min_valid_default) THEN h.temperature_min  END) AS temperature_min,
    MAX(CASE WHEN h.temperature_valid_n > COALESCE(min_valid_temperature, min_valid_default) THEN h.temperature_max  END) AS temperature_max,
    SUM(CASE WHEN h.temperature_valid_n > COALESCE(min_valid_temperature, min_valid_default) THEN h.temperature_valid_n ELSE 0 END) AS temperature_valid_n,
    SUM(CASE WHEN h.temperature_valid_n > COALESCE(min_valid_temperature, min_valid_default) THEN 1 ELSE 0 END) AS temperature_hours_n,

    /* Humidity */
    AVG(CASE WHEN h.humidity_valid_n > COALESCE(min_valid_humidity, min_valid_default) THEN h.humidity_mean END) AS humidity_mean,
    MIN(CASE WHEN h.humidity_valid_n > COALESCE(min_valid_humidity, min_valid_default) THEN h.humidity_min  END) AS humidity_min,
    MAX(CASE WHEN h.humidity_valid_n > COALESCE(min_valid_humidity, min_valid_default) THEN h.humidity_max  END) AS humidity_max,
    SUM(CASE WHEN h.humidity_valid_n > COALESCE(min_valid_humidity, min_valid_default) THEN h.humidity_valid_n ELSE 0 END) AS humidity_valid_n,
    SUM(CASE WHEN h.humidity_valid_n > COALESCE(min_valid_humidity, min_valid_default) THEN 1 ELSE 0 END) AS humidity_hours_n,

    /* Pressure */
    AVG(CASE WHEN h.pressure_valid_n > COALESCE(min_valid_pressure, min_valid_default) THEN h.pressure_mean END) AS pressure_mean,
    MIN(CASE WHEN h.pressure_valid_n > COALESCE(min_valid_pressure, min_valid_default) THEN h.pressure_min  END) AS pressure_min,
    MAX(CASE WHEN h.pressure_valid_n > COALESCE(min_valid_pressure, min_valid_default) THEN h.pressure_max  END) AS pressure_max,
    SUM(CASE WHEN h.pressure_valid_n > COALESCE(min_valid_pressure, min_valid_default) THEN h.pressure_valid_n ELSE 0 END) AS pressure_valid_n,
    SUM(CASE WHEN h.pressure_valid_n > COALESCE(min_valid_pressure, min_valid_default) THEN 1 ELSE 0 END) AS pressure_hours_n,

    /* Sound */
    AVG(CASE WHEN h.sound_valid_n > COALESCE(min_valid_sound, min_valid_default) THEN h.sound_mean END) AS sound_mean,
    MIN(CASE WHEN h.sound_valid_n > COALESCE(min_valid_sound, min_valid_default) THEN h.sound_min  END) AS sound_min,
    MAX(CASE WHEN h.sound_valid_n > COALESCE(min_valid_sound, min_valid_default) THEN h.sound_max  END) AS sound_max,
    SUM(CASE WHEN h.sound_valid_n > COALESCE(min_valid_sound, min_valid_default) THEN h.sound_valid_n ELSE 0 END) AS sound_valid_n,
    SUM(CASE WHEN h.sound_valid_n > COALESCE(min_valid_sound, min_valid_default) THEN 1 ELSE 0 END) AS sound_hours_n,

    /* UVB */
    AVG(CASE WHEN h.uvb_valid_n > COALESCE(min_valid_uvb, min_valid_default) THEN h.uvb_mean END) AS uvb_mean,
    MIN(CASE WHEN h.uvb_valid_n > COALESCE(min_valid_uvb, min_valid_default) THEN h.uvb_min  END) AS uvb_min,
    MAX(CASE WHEN h.uvb_valid_n > COALESCE(min_valid_uvb, min_valid_default) THEN h.uvb_max  END) AS uvb_max,
    SUM(CASE WHEN h.uvb_valid_n > COALESCE(min_valid_uvb, min_valid_default) THEN h.uvb_valid_n ELSE 0 END) AS uvb_valid_n,
    SUM(CASE WHEN h.uvb_valid_n > COALESCE(min_valid_uvb, min_valid_default) THEN 1 ELSE 0 END) AS uvb_hours_n,

    /* Light */
    AVG(CASE WHEN h.light_valid_n > COALESCE(min_valid_light, min_valid_default) THEN h.light_mean END) AS light_mean,
    MIN(CASE WHEN h.light_valid_n > COALESCE(min_valid_light, min_valid_default) THEN h.light_min  END) AS light_min,
    MAX(CASE WHEN h.light_valid_n > COALESCE(min_valid_light, min_valid_default) THEN h.light_max  END) AS light_max,
    SUM(CASE WHEN h.light_valid_n > COALESCE(min_valid_light, min_valid_default) THEN h.light_valid_n ELSE 0 END) AS light_valid_n,
    SUM(CASE WHEN h.light_valid_n > COALESCE(min_valid_light, min_valid_default) THEN 1 ELSE 0 END) AS light_hours_n,

    /* Total hourly rows contributing (regardless of thresholds) */
    SUM(h.myair_records_n) AS records_n

  FROM myair_hourly AS h
  WHERE (date_from IS NULL OR h.date >= date_from)
    AND (date_to   IS NULL OR h.date <= date_to)
    AND (userId    IS NULL OR h.userId = userId)
    AND (deviceId  IS NULL OR h.deviceId = deviceId)
  GROUP BY h.userId, h.deviceId, h.firmware, h.date
  ORDER BY h.userId, h.deviceId, h.firmware, h.date;

END//

DELIMITER ;

