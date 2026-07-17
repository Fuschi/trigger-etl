-- =========================================================
-- vw_active_accounts.sql
--
-- View of active TRIGGER accounts belonging to the four
-- participating countries.
--
-- An account is considered active when last_login is
-- available. The country code is derived from the first
-- two characters of the email address.
-- =========================================================

CREATE OR REPLACE VIEW active_accounts AS
SELECT
  id AS userId,
  UPPER(LEFT(email, 2)) AS nationality,
  email,
  last_login
FROM accounts
WHERE last_login IS NOT NULL
  AND UPPER(LEFT(email, 2)) IN (
    'CH',
    'DE',
    'GR',
    'IT'
  );
