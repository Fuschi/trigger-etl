CREATE OR REPLACE VIEW vw_active_accounts AS
SELECT
    id,
    email,
    last_login,
    UPPER(LEFT(email, 2)) AS country
FROM accounts
WHERE last_login IS NOT NULL
  AND LEFT(email, 2) IN ('CH','DE','GR','IT');

