package com.smartfoodai.backend.foods.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ImportExternalFoodRequest(@NotBlank @Size(max = 120) String name) {}
