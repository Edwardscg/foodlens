-- Aplicar una sola vez si estas columnas todavía no existen.
-- source_fdc_id conserva el origen aunque el usuario edite su copia privada.
ALTER TABLE custom_foods
    ADD COLUMN source_fdc_id BIGINT NULL,
    ADD COLUMN source_imported_at DATETIME(6) NULL;
