DELIMITER //

CREATE OR REPLACE PROCEDURE sp_active_accounts()
BEGIN
  SELECT
      id AS userId,
      UPPER(LEFT(email, 2)) AS country,
      email,
      last_login
  FROM accounts
  WHERE last_login IS NOT NULL
    AND LEFT(email, 2) IN ('CH','DE','GR','IT');
END//

DELIMITER ;

