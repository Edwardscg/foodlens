package com.smartfoodai.backend.water.dto;
import jakarta.validation.constraints.*;
public record WaterGoalRequest(@NotNull @Min(1) @Max(10000) Integer goalMl) {}
