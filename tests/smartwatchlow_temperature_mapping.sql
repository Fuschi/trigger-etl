-- Run in a scratch MariaDB 10.11 session; this does not access or write study tables.
-- Expected: user 1=no swap; user 2=swap; user 3=no swap (mixed);
-- user 4=no swap (insufficient classified buckets); user 5=no swap (uncertain).
WITH RECURSIVE seq AS (
  SELECT 1 AS n UNION ALL SELECT n + 1 FROM seq WHERE n < 20
),
samples AS (
  SELECT 1 AS userId, n, 32.0 AS body_raw, 36.5 AS skin_raw FROM seq
  UNION ALL SELECT 2, n, 36.5, 32.0 FROM seq
  UNION ALL SELECT 3, n, IF(n <= 10, 36.5, 32.0),
                                 IF(n <= 10, 32.0, 36.5) FROM seq
  UNION ALL SELECT 4, n, 36.5, 32.0 FROM seq WHERE n <= 8
  UNION ALL SELECT 5, n, 36.0, 36.3 FROM seq
),
votes AS (
  SELECT userId, n,
    CASE WHEN ABS(skin_raw - 36.5) - ABS(body_raw - 36.5) > 0.7 THEN 1
         WHEN ABS(skin_raw - 36.5) - ABS(body_raw - 36.5) < -0.7 THEN 0
         ELSE NULL END AS swap_vote
  FROM samples
),
daily AS (
  SELECT userId, COUNT(swap_vote) AS classified_n, AVG(swap_vote) AS p_swap
  FROM votes GROUP BY userId
)
SELECT userId, classified_n, p_swap,
       (classified_n >= 12 AND p_swap >= 0.8) AS should_swap
FROM daily ORDER BY userId;
