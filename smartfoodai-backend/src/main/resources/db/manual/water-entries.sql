-- Ejecutar en la misma base de datos del backend. Requiere users.
CREATE TABLE IF NOT EXISTS water_entries (
 id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
 user_id BIGINT NOT NULL,
 request_id VARCHAR(36) NOT NULL,
 amount INT NOT NULL,
 recorded_at DATETIME(6) NOT NULL,
 time_zone VARCHAR(64) NOT NULL,
 CONSTRAINT uk_water_request UNIQUE(user_id,request_id),
 INDEX ix_water_user_date(user_id,recorded_at),
 CONSTRAINT fk_water_user FOREIGN KEY(user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
