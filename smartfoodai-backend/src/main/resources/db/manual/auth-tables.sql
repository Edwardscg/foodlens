-- Ejecutar manualmente solo sobre una BD de desarrollo seleccionada.
-- No elimina ni altera tablas existentes. Si ya existen, comparar su estructura.
CREATE TABLE IF NOT EXISTS users (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    birth_date DATE,
    sex ENUM('M','F','OTHER'),
    weight_kg DECIMAL(38,2),
    height_cm DECIMAL(38,2),
    activity_level ENUM('sedentary','light','moderate','active','very_active'),
    goal ENUM('maintain','lose','gain','improve_habits'),
    daily_calorie_goal INT,
    daily_water_goal_ml INT,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    CONSTRAINT uk_users_email UNIQUE (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    token_hash VARCHAR(255) NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    revoked BIT(1) NOT NULL,
    created_at DATETIME(6) NOT NULL,
    CONSTRAINT uk_refresh_token_hash UNIQUE (token_hash),
    CONSTRAINT fk_refresh_user FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX ix_refresh_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Compatibilidad con la entidad PasswordResetToken que ya tiene tu proyecto.
-- Este paquete no activa endpoints ni envío de correo de recuperación.
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    token_hash VARCHAR(255) NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    used BIT(1) NOT NULL,
    created_at DATETIME(6) NOT NULL,
    CONSTRAINT uk_reset_token_hash UNIQUE (token_hash),
    CONSTRAINT fk_reset_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
