package com.smartfoodai.backend.foods.dto;

import java.math.BigDecimal;

public record ExternalFoodDetail(long fdcId, String name, String dataType,
        BigDecimal calories, BigDecimal proteinG, BigDecimal carbsG, BigDecimal fatG) {
    public boolean complete() {
        return calories != null && proteinG != null && carbsG != null && fatG != null;
    }
}
