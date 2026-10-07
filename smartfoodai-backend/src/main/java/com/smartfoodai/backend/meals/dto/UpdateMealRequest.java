package com.smartfoodai.backend.meals.dto;

import com.smartfoodai.backend.meals.entity.MealType;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.util.List;
import java.time.Instant;

public record UpdateMealRequest(@NotNull @PositiveOrZero Long version,
        @NotNull MealType mealType,
        @NotNull @Size(max = 50) List<@NotNull @Valid Item> items,
        @Size(max = 50) List<CreateMealRequest.@NotNull @Valid Item> addedItems,
        Instant consumedAt, @Size(max = 64) String timeZone) {
    public record Item(@NotNull @Positive Long id,
            @NotNull @DecimalMin("0.01") @DecimalMax("10000")
            @Digits(integer = 5, fraction = 2) BigDecimal quantity) {}
}
