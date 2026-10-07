-- Ejecutar en la base de datos usada por el backend, despuÃ©s de users y custom_foods.
-- Son tablas nuevas. Si ya existen, comparar su esquema antes de ejecutar.
CREATE TABLE meals (
    id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    meal_type VARCHAR(20) NOT NULL,
    consumed_at DATETIME(6) NOT NULL,
    time_zone VARCHAR(64) NOT NULL,
    origin VARCHAR(20) NOT NULL,
    created_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    INDEX idx_meals_user_consumed (user_id, consumed_at),
    CONSTRAINT fk_meals_user FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE TABLE meal_items (
    id BIGINT NOT NULL AUTO_INCREMENT,
    meal_id BIGINT NOT NULL,
    food_id BIGINT NOT NULL,
    name VARCHAR(120) NOT NULL,
    basis VARCHAR(20) NOT NULL,
    quantity DECIMAL(7,2) NOT NULL,
    unit VARCHAR(20) NOT NULL,
    base_calories DECIMAL(15,2) NOT NULL,
    base_protein_g DECIMAL(15,2) NOT NULL,
    base_carbs_g DECIMAL(15,2) NOT NULL,
    base_fat_g DECIMAL(15,2) NOT NULL,
    calories DECIMAL(15,2) NOT NULL,
    protein_g DECIMAL(15,2) NOT NULL,
    carbs_g DECIMAL(15,2) NOT NULL,
    fat_g DECIMAL(15,2) NOT NULL,
    PRIMARY KEY (id),
    INDEX idx_meal_items_meal (meal_id),
    CONSTRAINT fk_meal_items_meal FOREIGN KEY (meal_id) REFERENCES meals(id)
);
