-- Ejecutar en la base configurada, después de crear meals.
-- Fotos JPEG reencodificadas; acceso únicamente mediante API autenticada.
CREATE TABLE meal_photos (
    meal_id BIGINT NOT NULL,
    image LONGBLOB NOT NULL,
    PRIMARY KEY (meal_id),
    CONSTRAINT fk_meal_photos_meal FOREIGN KEY (meal_id)
        REFERENCES meals(id) ON DELETE CASCADE
);
