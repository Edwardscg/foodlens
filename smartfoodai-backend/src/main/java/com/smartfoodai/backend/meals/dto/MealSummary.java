package com.smartfoodai.backend.meals.dto;

import java.math.BigDecimal;

public record MealSummary(Long mealCount, BigDecimal calories, BigDecimal proteinG,
                          BigDecimal carbsG, BigDecimal fatG) {}
