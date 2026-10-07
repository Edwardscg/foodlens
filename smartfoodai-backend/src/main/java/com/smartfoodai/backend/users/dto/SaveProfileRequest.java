package com.smartfoodai.backend.users.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record SaveProfileRequest(
        @Valid @NotNull(message = "Completa los datos del perfil") ProfileData profile,
        @NotNull(message = "Elige una meta manual o sugerida") CalorieGoalSource goalSource,
        @Positive(message = "La meta debe ser un entero mayor que cero") Integer dailyCalorieGoal
) {}
