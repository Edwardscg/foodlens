package com.smartfoodai.backend.auth.dto;

import jakarta.validation.constraints.*;
import java.nio.charset.StandardCharsets;

public record LoginRequest(
        @NotBlank(message = "El correo es obligatorio")
        @Email(message = "El correo no tiene un formato válido")
        @Size(max = 254, message = "El correo no debe superar los 254 caracteres")
        String email,
        @NotBlank(message = "La contraseña es obligatoria") String password
) {
    @AssertTrue(message = "La contraseña no debe superar los 72 bytes UTF-8")
    public boolean isPasswordWithinByteLimit() {
        return password == null || password.getBytes(StandardCharsets.UTF_8).length <= 72;
    }
    @Override public String toString() { return "LoginRequest[redacted]"; }
}
