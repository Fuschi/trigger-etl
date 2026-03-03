DELIMITER //

CREATE OR REPLACE PROCEDURE active_accounts()
BEGIN
    SELECT
        id,
        email,
        last_login,
        UPPER(SUBSTRING(email, 1, 2)) AS country
    FROM accounts
    WHERE last_login IS NOT NULL
      AND email REGEXP '^(CH|DE|GR|IT)';
END //

DELIMITER ;