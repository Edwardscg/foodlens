package com.smartfoodai.backend.meals.dto;

import jakarta.validation.constraints.*;

public record ResolvePhotoFoodRequest(@NotBlank @Size(max = 120) String name,
                                     @Size(max = 120) String nutritionQuery) {}
