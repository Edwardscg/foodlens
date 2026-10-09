package com.smartfoodai.backend.auth.dto;

import jakarta.validation.constraints.*;
import java.nio.charset.StandardCharsets;

public record ResetPasswordRequest(
        @NotBlank(message = "Ingresa el código recibido por correo")
        @Pattern(regexp = "[A-Za-z0-9_-]{43}", message = "Copia el código completo del correo")
        String token,
        @NotBlank(message = "Ingresa la nueva contraseña")
        @Pattern(regexp = "(?s).{8,}", message = "Usa al menos 8 caracteres")
        String newPassword
) {
    @AssertTrue(message = "La contraseña no debe superar los 72 bytes UTF-8")
    public boolean isNewPasswordWithinByteLimit() {
        return newPassword == null || newPassword.getBytes(StandardCharsets.UTF_8).length <= 72;
    }
}
