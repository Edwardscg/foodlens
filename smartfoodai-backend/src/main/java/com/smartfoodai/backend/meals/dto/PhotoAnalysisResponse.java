package com.smartfoodai.backend.meals.dto;

import java.math.BigDecimal;
import java.util.List;

public record PhotoAnalysisResponse(List<DetectedFood> foods) {
    public record DetectedFood(String name, BigDecimal estimatedGrams) {}
}
