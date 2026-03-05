DELIMITER //

CREATE OR REPLACE PROCEDURE sp_smartwatchlow_daily(
  IN p_min_valid_default INT,

  IN p_date_from DATE,         -- NULL = no lower bound
  IN p_date_to   DATE,         -- NULL = no upper bound
  IN p_userId    BIGINT,       -- NULL = all
  IN p_deviceId  VARCHAR(128), -- NULL = all

  /* Optional per-metric thresholds (NULL = use p_min_valid_default) */
  IN p_min_valid_steps    INT,
  IN p_min_valid_cal      INT,
  IN p_min_valid_bphigh   INT,
  IN p_min_valid_bplow    INT,
  IN p_min_valid_bodytemp INT,
  IN p_min_valid_skintemp INT
)
BEGIN
  /*
    smartwatchlow_hourly -> daily aggregation (no persistence, returns a result set)

    Rule (per metric X):
      - Include an hour only if X_valid_n > threshold(X)
      - threshold(X) = COALESCE(p_min_valid_X, p_min_valid_default)

    Outputs (per metric X):
      - Mean/min/max computed only over included hours (for mean/min/max metrics)
      - Sum computed only over included hours (for sum metrics)
      - X_valid_n = SUM(X_valid_n) over included hours
      - X_hours_n = number of included hours

    Extra:
      - records_n = SUM(smartwatchlow_records_n) across all hours (regardless of thresholds)
  */

  SELECT
    h.userId,
    h.deviceId,
    h.firmware,
    h.date,

    /* -------------------------
       Steps (validity: steps_valid_n)
    ------------------------- */
    SUM(CASE WHEN h.steps_valid_n > COALESCE(p_min_valid_steps, p_min_valid_default) THEN h.steps_sum ELSE 0 END) AS steps_sum,
    SUM(CASE WHEN h.steps_valid_n > COALESCE(p_min_valid_steps, p_min_valid_default) THEN h.steps_valid_n ELSE 0 END) AS steps_valid_n,
    SUM(CASE WHEN h.steps_valid_n > COALESCE(p_min_valid_steps, p_min_valid_default) THEN 1 ELSE 0 END) AS steps_hours_n,

    /* -------------------------
       Calories (validity: cal_valid_n)
    ------------------------- */
    SUM(CASE WHEN h.cal_valid_n > COALESCE(p_min_valid_cal, p_min_valid_default) THEN h.cal_sum ELSE 0 END) AS cal_sum,
    SUM(CASE WHEN h.cal_valid_n > COALESCE(p_min_valid_cal, p_min_valid_default) THEN h.cal_valid_n ELSE 0 END) AS cal_valid_n,
    SUM(CASE WHEN h.cal_valid_n > COALESCE(p_min_valid_cal, p_min_valid_default) THEN 1 ELSE 0 END) AS cal_hours_n,

    /* -------------------------
       Blood pressure (validity: bphigh_valid_n / bplow_valid_n)
    ------------------------- */
    AVG(CASE WHEN h.bphigh_valid_n > COALESCE(p_min_valid_bphigh, p_min_valid_default) THEN h.bphigh_mean END) AS bphigh_mean,
    MIN(CASE WHEN h.bphigh_valid_n > COALESCE(p_min_valid_bphigh, p_min_valid_default) THEN h.bphigh_min  END) AS bphigh_min,
    MAX(CASE WHEN h.bphigh_valid_n > COALESCE(p_min_valid_bphigh, p_min_valid_default) THEN h.bphigh_max  END) AS bphigh_max,
    SUM(CASE WHEN h.bphigh_valid_n > COALESCE(p_min_valid_bphigh, p_min_valid_default) THEN h.bphigh_valid_n ELSE 0 END) AS bphigh_valid_n,
    SUM(CASE WHEN h.bphigh_valid_n > COALESCE(p_min_valid_bphigh, p_min_valid_default) THEN 1 ELSE 0 END) AS bphigh_hours_n,

    AVG(CASE WHEN h.bplow_valid_n  > COALESCE(p_min_valid_bplow, p_min_valid_default) THEN h.bplow_mean END) AS bplow_mean,
    MIN(CASE WHEN h.bplow_valid_n  > COALESCE(p_min_valid_bplow, p_min_valid_default) THEN h.bplow_min  END) AS bplow_min,
    MAX(CASE WHEN h.bplow_valid_n  > COALESCE(p_min_valid_bplow, p_min_valid_default) THEN h.bplow_max  END) AS bplow_max,
    SUM(CASE WHEN h.bplow_valid_n  > COALESCE(p_min_valid_bplow, p_min_valid_default) THEN h.bplow_valid_n ELSE 0 END) AS bplow_valid_n,
    SUM(CASE WHEN h.bplow_valid_n  > COALESCE(p_min_valid_bplow, p_min_valid_default) THEN 1 ELSE 0 END) AS bplow_hours_n,

    /* -------------------------
       Body temperature (validity: bodytemp_valid_n)
    ------------------------- */
    AVG(CASE WHEN h.bodytemp_valid_n > COALESCE(p_min_valid_bodytemp, p_min_valid_default) THEN h.bodytemp_mean END) AS bodytemp_mean,
    MIN(CASE WHEN h.bodytemp_valid_n > COALESCE(p_min_valid_bodytemp, p_min_valid_default) THEN h.bodytemp_min  END) AS bodytemp_min,
    MAX(CASE WHEN h.bodytemp_valid_n > COALESCE(p_min_valid_bodytemp, p_min_valid_default) THEN h.bodytemp_max  END) AS bodytemp_max,
    SUM(CASE WHEN h.bodytemp_valid_n > COALESCE(p_min_valid_bodytemp, p_min_valid_default) THEN h.bodytemp_valid_n ELSE 0 END) AS bodytemp_valid_n,
    SUM(CASE WHEN h.bodytemp_valid_n > COALESCE(p_min_valid_bodytemp, p_min_valid_default) THEN 1 ELSE 0 END) AS bodytemp_hours_n,

    /* -------------------------
       Skin temperature (validity: skintemp_valid_n)
    ------------------------- */
    AVG(CASE WHEN h.skintemp_valid_n > COALESCE(p_min_valid_skintemp, p_min_valid_default) THEN h.skintemp_mean END) AS skintemp_mean,
    MIN(CASE WHEN h.skintemp_valid_n > COALESCE(p_min_valid_skintemp, p_min_valid_default) THEN h.skintemp_min  END) AS skintemp_min,
    MAX(CASE WHEN h.skintemp_valid_n > COALESCE(p_min_valid_skintemp, p_min_valid_default) THEN h.skintemp_max  END) AS skintemp_max,
    SUM(CASE WHEN h.skintemp_valid_n > COALESCE(p_min_valid_skintemp, p_min_valid_default) THEN h.skintemp_valid_n ELSE 0 END) AS skintemp_valid_n,
    SUM(CASE WHEN h.skintemp_valid_n > COALESCE(p_min_valid_skintemp, p_min_valid_default) THEN 1 ELSE 0 END) AS skintemp_hours_n,

    /* Total hourly rows contributing (regardless of thresholds) */
    SUM(h.smartwatchlow_records_n) AS records_n

  FROM smartwatchlow_hourly AS h
  WHERE (p_date_from IS NULL OR h.date >= p_date_from)
    AND (p_date_to   IS NULL OR h.date <= p_date_to)
    AND (p_userId    IS NULL OR h.userId = p_userId)
    AND (p_deviceId  IS NULL OR h.deviceId = p_deviceId)

  GROUP BY h.userId, h.deviceId, h.firmware, h.date
  ORDER BY h.userId, h.deviceId, h.firmware, h.date;

END//

DELIMITER ;

