-- Run manually on the application's existing MySQL schema before starting this backend.
-- Additive only. Existing user ids, dates and profile data remain unchanged.
-- Inspect SHOW CREATE TABLE users first. Existing columns are not repaired by this script.
SET @profile_ddl = IF(
    EXISTS (SELECT 1 FROM information_schema.columns
            WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'declared_age'),
    'SELECT 1', 'ALTER TABLE users ADD COLUMN declared_age INT NULL');
PREPARE profile_statement FROM @profile_ddl;
EXECUTE profile_statement;
DEALLOCATE PREPARE profile_statement;

SET @profile_ddl = IF(
    EXISTS (SELECT 1 FROM information_schema.columns
            WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'calorie_goal_source'),
    'SELECT 1', 'ALTER TABLE users ADD COLUMN calorie_goal_source VARCHAR(16) NULL');
PREPARE profile_statement FROM @profile_ddl;
EXECUTE profile_statement;
DEALLOCATE PREPARE profile_statement;
