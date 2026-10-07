package com.smartfoodai.backend.meals.dto;

import java.util.List;

public record MealPage(List<MealResponse> items, int page, int size,
                       long totalElements, int totalPages) {}
