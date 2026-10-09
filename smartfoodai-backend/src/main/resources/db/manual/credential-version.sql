-- Ejecutar en la BD del backend antes de iniciar esta versión.
-- Invalida sesiones previas al cambiar la contraseña; conserva usuarios y datos.
SET @ddl = IF(EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'credential_version'),
    'SELECT 1', 'ALTER TABLE users ADD COLUMN credential_version BIGINT NOT NULL DEFAULT 0');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
