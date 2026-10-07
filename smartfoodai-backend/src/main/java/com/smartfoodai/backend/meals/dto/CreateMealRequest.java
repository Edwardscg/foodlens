package com.smartfoodai.backend.meals.dto;

import com.smartfoodai.backend.meals.entity.MealType;
import com.smartfoodai.backend.meals.entity.MealUnit;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

public record CreateMealRequest(
        @NotNull MealType mealType,
        @NotNull Instant consumedAt,
        @NotBlank @Size(max = 64) String timeZone,
        @NotEmpty @Size(max = 50) List<@NotNull @Valid Item> items) {
    public record Item(
            @NotNull @Positive Long foodId,
            @NotNull @DecimalMin("0.01") @DecimalMax("10000")
            @Digits(integer = 5, fraction = 2) BigDecimal quantity,
            @NotNull MealUnit unit) {}
}
