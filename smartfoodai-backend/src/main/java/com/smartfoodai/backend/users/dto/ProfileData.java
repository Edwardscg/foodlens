package com.smartfoodai.backend.users.dto;

import com.smartfoodai.backend.auth.entity.ActivityLevel;
import com.smartfoodai.backend.auth.entity.Goal;
import com.smartfoodai.backend.auth.entity.Sex;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;

public record ProfileData(
        @Size(max = 120, message = "El nombre admite hasta 120 caracteres") String name,
        @NotNull(message = "Ingresa tu edad")
        @Min(value = 15, message = "La edad mínima es 15 años")
        @Max(value = 100, message = "La edad máxima admitida es 100 años") Integer age,
        @NotNull(message = "Selecciona una opción de sexo") Sex sex,
        @NotNull(message = "Ingresa tu peso")
        @DecimalMin(value = "30", message = "El peso mínimo admitido es 30 kg")
        @DecimalMax(value = "300", message = "El peso máximo admitido es 300 kg")
        @Digits(integer = 3, fraction = 2, message = "Usa hasta 2 decimales") BigDecimal weightKg,
        @NotNull(message = "Ingresa tu altura")
        @DecimalMin(value = "100", message = "La altura mínima admitida es 100 cm")
        @DecimalMax(value = "250", message = "La altura máxima admitida es 250 cm")
        @Digits(integer = 3, fraction = 2, message = "Usa hasta 2 decimales") BigDecimal heightCm,
        @NotNull(message = "Selecciona tu actividad") ActivityLevel activityLevel,
        @NotNull(message = "Selecciona tu objetivo") Goal goal
) {}
