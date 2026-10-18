package com.smartfoodai.backend.foods.dto;

import java.util.List;

public record ExternalFoodPage(List<Item> items, int page, int totalPages) {
    public record Item(long fdcId, String name, String dataType) {}
}
