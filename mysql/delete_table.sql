

DELIMITER $$
DROP PROCEDURE IF EXISTS `delete_table`$$
CREATE PROCEDURE IF NOT EXISTS `delete_table`(IN `newtablename` VARCHAR(255))
BEGIN
    -- Remove Table Config
    DELETE FROM tableconfig WHERE tablename = CONCAT('data_',newtablename);

    -- DROP Table
    SET @c = CONCAT('DROP TABLE IF EXISTS data_', newtablename);

    PREPARE QUERY from @c;
    EXECUTE QUERY;
    DEALLOCATE PREPARE QUERY;

END$$
DELIMITER ;


