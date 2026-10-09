package com.smartfoodai.backend.water.dto;
import jakarta.validation.constraints.*;
public record WaterRequest(@NotNull @Min(1) @Max(10000) Integer amount,
        @NotBlank @Size(max=36) @Pattern(regexp="[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}") String requestId,
        @NotBlank @Size(max=64) String timeZone) {}
