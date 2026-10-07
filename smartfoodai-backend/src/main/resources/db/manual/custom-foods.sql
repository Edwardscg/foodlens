-- Execute once in the application's existing MySQL database, before starting the backend.
-- Requires the users table from the authentication module. Does not alter existing tables.
CREATE TABLE IF NOT EXISTS custom_foods (
    id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    name VARCHAR(120) NOT NULL,
    basis VARCHAR(20) NOT NULL,
    calories DECIMAL(9,2) NOT NULL,
    protein_g DECIMAL(9,2) NOT NULL,
    carbs_g DECIMAL(9,2) NOT NULL,
    fat_g DECIMAL(9,2) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (id),
    INDEX ix_custom_foods_user_created (user_id, created_at, id),
    CONSTRAINT fk_custom_foods_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT ck_custom_foods_basis CHECK (basis IN ('PER_100_G', 'PER_SERVING')),
    CONSTRAINT ck_custom_foods_nutrients CHECK (
        calories >= 0 AND protein_g >= 0 AND carbs_g >= 0 AND fat_g >= 0
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
