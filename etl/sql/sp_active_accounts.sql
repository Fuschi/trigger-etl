CREATE OR REPLACE PROCEDURE sp_active_accounts()
BEGIN
  SELECT
      id,
      email,
      last_login,
      UPPER(LEFT(email, 2)) AS country
  FROM accounts
  WHERE last_login IS NOT NULL
    AND LEFT(email, 2) IN ('CH','DE','GR','IT');
END;
