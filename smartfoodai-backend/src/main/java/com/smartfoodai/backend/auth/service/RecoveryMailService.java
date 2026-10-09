package com.smartfoodai.backend.auth.service;

import com.smartfoodai.backend.common.exception.ApiException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.MailException;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;
import org.springframework.transaction.event.TransactionalEventListener;

@Service
@RequiredArgsConstructor
@Slf4j
public class RecoveryMailService {
    private final JavaMailSender sender;
    @Value("${app.recovery.enabled:false}")
    private boolean enabled;
    @Value("${app.recovery.from:}")
    private String from;

    // Deliberately not a record: default toString must not print the reset code.
    public static final class Delivery {
        private final String email;
        private final String code;
        public Delivery(String email, String code) { this.email = email; this.code = code; }
    }

    public void requireConfigured() {
        if (!enabled || from == null || from.isBlank()) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,
                    "La recuperación por correo todavía no está disponible. Inténtalo más tarde.");
        }
    }

    @TransactionalEventListener
    public void deliver(Delivery delivery) {
        var message = new SimpleMailMessage();
        message.setFrom(from);
        message.setTo(delivery.email);
        message.setSubject("Recupera tu acceso a Smart Food AI");
        message.setText("Copia este código en la pantalla Recuperar contraseña de Smart Food AI:\n\n"
                + delivery.code + "\n\nCaduca en 15 minutos y solo se puede usar una vez. "
                + "Si no solicitaste este cambio, ignora el mensaje. Tu contraseña sigue igual.");
        try {
            sender.send(message);
        } catch (MailException exception) {
            // Do not expose recipients, credentials or reset codes in responses/logs.
            log.warn("No se pudo entregar un correo de recuperación; revisar configuración SMTP.");
        }
    }
}
