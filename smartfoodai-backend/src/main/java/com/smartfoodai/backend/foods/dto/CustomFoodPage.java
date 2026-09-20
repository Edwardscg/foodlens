package com.smartfoodai.backend.foods.dto;

import java.util.List;

public record CustomFoodPage(List<CustomFoodResponse> items, int page, int size,
                             long totalElements, int totalPages) {}
