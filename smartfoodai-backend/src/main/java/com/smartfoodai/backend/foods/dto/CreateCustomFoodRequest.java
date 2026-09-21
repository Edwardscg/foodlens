package com.smartfoodai.backend.foods.dto;

import com.smartfoodai.backend.foods.entity.NutritionBasis;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;

public record CreateCustomFoodRequest(
        @NotBlank(message = "Ingresa el nombre del alimento")
        @Size(max = 120, message = "El nombre admite hasta 120 caracteres")
        String name,
        @NotNull(message = "Selecciona por 100 g o por porción")
        NutritionBasis basis,
        @NotNull(message = "Ingresa las calorías")
        @DecimalMin(value = "0", message = "Las calorías no pueden ser negativas")
        @Digits(integer = 7, fraction = 2, message = "Usa hasta 7 enteros y 2 decimales")
        BigDecimal calories,
        @NotNull(message = "Ingresa las proteínas")
        @DecimalMin(value = "0", message = "Las proteínas no pueden ser negativas")
        @Digits(integer = 7, fraction = 2, message = "Usa hasta 7 enteros y 2 decimales")
        BigDecimal proteinG,
        @NotNull(message = "Ingresa los carbohidratos")
        @DecimalMin(value = "0", message = "Los carbohidratos no pueden ser negativos")
        @Digits(integer = 7, fraction = 2, message = "Usa hasta 7 enteros y 2 decimales")
        BigDecimal carbsG,
        @NotNull(message = "Ingresa las grasas")
        @DecimalMin(value = "0", message = "Las grasas no pueden ser negativas")
        @Digits(integer = 7, fraction = 2, message = "Usa hasta 7 enteros y 2 decimales")
        BigDecimal fatG
) {}
