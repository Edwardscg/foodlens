package com.smartfoodai.backend.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record LogoutRequest(

        @NotBlank(message = "El refreshToken es obligatorio")
        String refreshToken
) {
}
