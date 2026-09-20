package com.smartfoodai.backend.foods.dto;

import com.smartfoodai.backend.foods.entity.NutritionBasis;
import java.math.BigDecimal;
import java.time.Instant;

public record CustomFoodResponse(Long id, String name, NutritionBasis basis,
                                 BigDecimal calories, BigDecimal proteinG,
                                 BigDecimal carbsG, BigDecimal fatG, Instant createdAt) {}
