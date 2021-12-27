
DELIMITER $$
DROP PROCEDURE IF EXISTS `create_keybased`$$
CREATE PROCEDURE IF NOT EXISTS `create_keybased`(IN `newtablename` VARCHAR(255))
BEGIN
    -- Generate a random hash
    SET @string = 'abcdefghijklmnopqrstuvwxyz0123456789';
    SET @i = 1;
    SET @new_authkey = '';

    WHILE (@i <= 32) DO
        SET @new_authkey = CONCAT(@new_authkey, SUBSTRING(@string, FLOOR(RAND() * 36 + 1), 1));
        SET @i = @i + 1;
    END WHILE;

    -- Print out
    SELECT newtablename as TableName, @new_authkey as AuthKey;

    -- Insert Table Config
    INSERT INTO tableconfig(tablename, authkey, mode) VALUE(newtablename, @new_authkey, 1);

    -- Create Config
    SET @c = CONCAT('CREATE TABLE IF NOT EXISTS data_', newtablename,'(
        `key` VARCHAR(255) PRIMARY KEY,
        `value` VARCHAR(1024),
        `created_on` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_on` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )');

    PREPARE QUERY from @c;
    EXECUTE QUERY;
    DEALLOCATE PREPARE QUERY;

END$$
DELIMITER ;



