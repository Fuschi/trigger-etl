DELIMITER //

CREATE OR REPLACE PROCEDURE sp_gps_daily(
  IN min_valid_default INT,

  IN date_from DATE,         -- NULL = no lower bound
  IN date_to   DATE,         -- NULL = no upper bound
  IN userId    BIGINT,       -- NULL = all
  IN deviceId  VARCHAR(128), -- NULL = all

  /* Optional per-metric thresholds (NULL = use min_valid_default) */
  IN min_valid_longitude INT,
  IN min_valid_latitude  INT,
  IN min_valid_accuracy  INT
)
BEGIN
  /*
    gps_hourly -> daily aggregation (no persistence, returns a result set)

    Rule (per metric X):
      - Include an hour only if X_valid_n > threshold(X)
      - threshold(X) = COALESCE(min_valid_X, min_valid_default)

    Outputs (per metric X):
      - X_mean / X_min / X_max computed only over included hours
      - X_valid_n = SUM(X_valid_n) over included hours
      - X_hours_n = number of included hours

    Extra:
      - records_n = SUM(gps_records_n) across all hours (regardless of thresholds)
  */

  SELECT
    h.userId,
    h.deviceId,
    h.firmware,
    h.date,

    /* -------------------------
       Longitude (validity: longitude_valid_n)
    ------------------------- */
    AVG(CASE WHEN h.longitude_valid_n > COALESCE(min_valid_longitude, min_valid_default) THEN h.longitude_mean END) AS longitude_mean,
    MIN(CASE WHEN h.longitude_valid_n > COALESCE(min_valid_longitude, min_valid_default) THEN h.longitude_min  END) AS longitude_min,
    MAX(CASE WHEN h.longitude_valid_n > COALESCE(min_valid_longitude, min_valid_default) THEN h.longitude_max  END) AS longitude_max,
    SUM(CASE WHEN h.longitude_valid_n > COALESCE(min_valid_longitude, min_valid_default) THEN h.longitude_valid_n ELSE 0 END) AS longitude_valid_n,
    SUM(CASE WHEN h.longitude_valid_n > COALESCE(min_valid_longitude, min_valid_default) THEN 1 ELSE 0 END) AS longitude_hours_n,

    /* -------------------------
       Latitude (validity: latitude_valid_n)
    ------------------------- */
    AVG(CASE WHEN h.latitude_valid_n > COALESCE(min_valid_latitude, min_valid_default) THEN h.latitude_mean END) AS latitude_mean,
    MIN(CASE WHEN h.latitude_valid_n > COALESCE(min_valid_latitude, min_valid_default) THEN h.latitude_min  END) AS latitude_min,
    MAX(CASE WHEN h.latitude_valid_n > COALESCE(min_valid_latitude, min_valid_default) THEN h.latitude_max  END) AS latitude_max,
    SUM(CASE WHEN h.latitude_valid_n > COALESCE(min_valid_latitude, min_valid_default) THEN h.latitude_valid_n ELSE 0 END) AS latitude_valid_n,
    SUM(CASE WHEN h.latitude_valid_n > COALESCE(min_valid_latitude, min_valid_default) THEN 1 ELSE 0 END) AS latitude_hours_n,

    /* -------------------------
       Accuracy (validity: accuracy_valid_n)
    ------------------------- */
    AVG(CASE WHEN h.accuracy_valid_n > COALESCE(min_valid_accuracy, min_valid_default) THEN h.accuracy_mean END) AS accuracy_mean,
    MIN(CASE WHEN h.accuracy_valid_n > COALESCE(min_valid_accuracy, min_valid_default) THEN h.accuracy_min  END) AS accuracy_min,
    MAX(CASE WHEN h.accuracy_valid_n > COALESCE(min_valid_accuracy, min_valid_default) THEN h.accuracy_max  END) AS accuracy_max,
    SUM(CASE WHEN h.accuracy_valid_n > COALESCE(min_valid_accuracy, min_valid_default) THEN h.accuracy_valid_n ELSE 0 END) AS accuracy_valid_n,
    SUM(CASE WHEN h.accuracy_valid_n > COALESCE(min_valid_accuracy, min_valid_default) THEN 1 ELSE 0 END) AS accuracy_hours_n,

    /* Total hourly rows contributing (regardless of thresholds) */
    SUM(h.gps_records_n) AS records_n

  FROM gps_hourly AS h
  WHERE (date_from IS NULL OR h.date >= date_from)
    AND (date_to   IS NULL OR h.date <= date_to)
    AND (userId    IS NULL OR h.userId = userId)
    AND (deviceId  IS NULL OR h.deviceId = deviceId)
  GROUP BY h.userId, h.deviceId, h.firmware, h.date
  ORDER BY h.userId, h.deviceId, h.firmware, h.date;

END//

DELIMITER ;

