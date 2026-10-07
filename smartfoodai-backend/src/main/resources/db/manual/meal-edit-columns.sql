-- Ejecutar después de manual-meals.sql. Conserva todos los registros existentes.
SET @ddl = IF(EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'meals' AND column_name = 'version'),
    'SELECT 1', 'ALTER TABLE meals ADD COLUMN version BIGINT NOT NULL DEFAULT 0');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @ddl = IF(EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'meals' AND column_name = 'updated_at'),
    'SELECT 1', 'ALTER TABLE meals ADD COLUMN updated_at DATETIME(6) NULL');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
