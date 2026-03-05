DELIMITER //

CREATE OR REPLACE PROCEDURE sp_smartwatchhigh_daily(
  IN p_min_valid_default INT,

  IN p_date_from DATE,         -- NULL = no lower bound
  IN p_date_to   DATE,         -- NULL = no upper bound
  IN p_userId    BIGINT,       -- NULL = all
  IN p_deviceId  VARCHAR(128), -- NULL = all

  /* Optional per-metric thresholds (NULL = use p_min_valid_default) */
  IN p_min_valid_heartrate  INT,
  IN p_min_valid_oxygens    INT,
  IN p_min_valid_breathrate INT,
  IN p_min_valid_sleeprate  INT
)
BEGIN
  /*
    smartwatchhigh_hourly -> daily aggregation (no persistence, returns a result set)

    Rule (per metric X):
      - Include an hour only if X_valid_n > threshold(X)
      - threshold(X) = COALESCE(p_min_valid_X, p_min_valid_default)

    Outputs (per metric X):
      - X_mean / X_min / X_max computed only over included hours
      - X_valid_n = SUM(X_valid_n) over included hours
      - X_hours_n = number of included hours

    Extra:
      - records_n = SUM(smartwatchhigh_records_n) across all hours (regardless of thresholds)
  */

  SELECT
    h.userId,
    h.deviceId,
    h.firmware,
    h.date,

    /* -------------------------
       Heart rate (validity: heartrate_valid_n)
    ------------------------- */
    AVG(CASE WHEN h.heartrate_valid_n > COALESCE(p_min_valid_heartrate, p_min_valid_default) THEN h.heartrate_mean END) AS heartrate_mean,
    MIN(CASE WHEN h.heartrate_valid_n > COALESCE(p_min_valid_heartrate, p_min_valid_default) THEN h.heartrate_min  END) AS heartrate_min,
    MAX(CASE WHEN h.heartrate_valid_n > COALESCE(p_min_valid_heartrate, p_min_valid_default) THEN h.heartrate_max  END) AS heartrate_max,
    SUM(CASE WHEN h.heartrate_valid_n > COALESCE(p_min_valid_heartrate, p_min_valid_default) THEN h.heartrate_valid_n ELSE 0 END) AS heartrate_valid_n,
    SUM(CASE WHEN h.heartrate_valid_n > COALESCE(p_min_valid_heartrate, p_min_valid_default) THEN 1 ELSE 0 END) AS heartrate_hours_n,

    /* -------------------------
       Oxygen saturation (validity: oxygens_valid_n)
    ------------------------- */
    AVG(CASE WHEN h.oxygens_valid_n > COALESCE(p_min_valid_oxygens, p_min_valid_default) THEN h.oxygens_mean END) AS oxygens_mean,
    MIN(CASE WHEN h.oxygens_valid_n > COALESCE(p_min_valid_oxygens, p_min_valid_default) THEN h.oxygens_min  END) AS oxygens_min,
    MAX(CASE WHEN h.oxygens_valid_n > COALESCE(p_min_valid_oxygens, p_min_valid_default) THEN h.oxygens_max  END) AS oxygens_max,
    SUM(CASE WHEN h.oxygens_valid_n > COALESCE(p_min_valid_oxygens, p_min_valid_default) THEN h.oxygens_valid_n ELSE 0 END) AS oxygens_valid_n,
    SUM(CASE WHEN h.oxygens_valid_n > COALESCE(p_min_valid_oxygens, p_min_valid_default) THEN 1 ELSE 0 END) AS oxygens_hours_n,

    /* -------------------------
       Breath rate (validity: breathrate_valid_n)
    ------------------------- */
    AVG(CASE WHEN h.breathrate_valid_n > COALESCE(p_min_valid_breathrate, p_min_valid_default) THEN h.breathrate_mean END) AS breathrate_mean,
    MIN(CASE WHEN h.breathrate_valid_n > COALESCE(p_min_valid_breathrate, p_min_valid_default) THEN h.breathrate_min  END) AS breathrate_min,
    MAX(CASE WHEN h.breathrate_valid_n > COALESCE(p_min_valid_breathrate, p_min_valid_default) THEN h.breathrate_max  END) AS breathrate_max,
    SUM(CASE WHEN h.breathrate_valid_n > COALESCE(p_min_valid_breathrate, p_min_valid_default) THEN h.breathrate_valid_n ELSE 0 END) AS breathrate_valid_n,
    SUM(CASE WHEN h.breathrate_valid_n > COALESCE(p_min_valid_breathrate, p_min_valid_default) THEN 1 ELSE 0 END) AS breathrate_hours_n,

    /* -------------------------
       Sleep rate (validity: sleeprate_valid_n)
    ------------------------- */
    AVG(CASE WHEN h.sleeprate_valid_n > COALESCE(p_min_valid_sleeprate, p_min_valid_default) THEN h.sleeprate_mean END) AS sleeprate_mean,
    MIN(CASE WHEN h.sleeprate_valid_n > COALESCE(p_min_valid_sleeprate, p_min_valid_default) THEN h.sleeprate_min  END) AS sleeprate_min,
    MAX(CASE WHEN h.sleeprate_valid_n > COALESCE(p_min_valid_sleeprate, p_min_valid_default) THEN h.sleeprate_max  END) AS sleeprate_max,
    SUM(CASE WHEN h.sleeprate_valid_n > COALESCE(p_min_valid_sleeprate, p_min_valid_default) THEN h.sleeprate_valid_n ELSE 0 END) AS sleeprate_valid_n,
    SUM(CASE WHEN h.sleeprate_valid_n > COALESCE(p_min_valid_sleeprate, p_min_valid_default) THEN 1 ELSE 0 END) AS sleeprate_hours_n,

    /* Total hourly rows contributing (regardless of thresholds) */
    SUM(h.smartwatchhigh_records_n) AS records_n

  FROM smartwatchhigh_hourly AS h
  WHERE (p_date_from IS NULL OR h.date >= p_date_from)
    AND (p_date_to   IS NULL OR h.date <= p_date_to)
    AND (p_userId    IS NULL OR h.userId = p_userId)
    AND (p_deviceId  IS NULL OR h.deviceId = p_deviceId)

  GROUP BY h.userId, h.deviceId, h.firmware, h.date
  ORDER BY h.userId, h.deviceId, h.firmware, h.date;

END//

DELIMITER ;

