package com.smartfoodai.backend.meals.dto;

import com.smartfoodai.backend.foods.entity.NutritionBasis;
import com.smartfoodai.backend.meals.entity.MealType;
import com.smartfoodai.backend.meals.entity.MealUnit;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

public record MealResponse(Long id, MealType mealType, Instant consumedAt,
        String timeZone, String origin, Instant createdAt, List<Item> items,
        Nutrition totals) {
    public record Nutrition(BigDecimal calories, BigDecimal proteinG,
                            BigDecimal carbsG, BigDecimal fatG) {}
    public record Item(Long foodId, String name, NutritionBasis basis,
                       BigDecimal quantity, MealUnit unit, Nutrition baseNutrition,
                       Nutrition consumedNutrition) {}
}
