package com.smartfoodai.backend.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record RefreshRequest(
        @NotBlank(message = "El refresh token es obligatorio")
        @Size(max = 512, message = "El refresh token no es válido") String refreshToken
) {
    @Override public String toString() { return "RefreshRequest[redacted]"; }
}
