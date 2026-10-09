package com.smartfoodai.backend.auth.service;

import com.smartfoodai.backend.auth.dto.ResetPasswordRequest;
import com.smartfoodai.backend.auth.entity.PasswordResetToken;
import com.smartfoodai.backend.auth.repository.*;
import com.smartfoodai.backend.common.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.Locale;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class PasswordRecoveryService {
    private final UserRepository users;
    private final PasswordResetTokenRepository resets;
    private final RefreshTokenRepository refreshTokens;
    private final PasswordEncoder passwords;
    private final RecoveryMailService mail;
    private final ApplicationEventPublisher events;
    private final SecureRandom random = new SecureRandom();
    private final Map<String, Instant> recent = new HashMap<>();

    @Transactional
    public void request(String rawEmail) {
        mail.requireConfigured();
        String email = rawEmail.strip().toLowerCase(Locale.ROOT);
        if (!allow(email)) return;
        var user = users.findForUpdateByEmail(email).orElse(null);
        if (user == null) return; // Same response for existing and unknown accounts.
        resets.findByUserIdAndUsedFalse(user.getId()).forEach(token -> token.setUsed(true));
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        String code = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        resets.save(PasswordResetToken.builder().userId(user.getId()).tokenHash(hash(code))
                .expiresAt(Instant.now().plusSeconds(900)).used(false).build());
        events.publishEvent(new RecoveryMailService.Delivery(email, code));
    }

    // Bounded single-instance limit; the response does not reveal account existence.
    private synchronized boolean allow(String email) {
        Instant now = Instant.now();
        recent.values().removeIf(at -> !at.isAfter(now.minusSeconds(60)));
        String key = hash(email);
        if (recent.containsKey(key) || recent.size() >= 30) return false;
        recent.put(key, now);
        return true;
    }

    @Transactional
    public void reset(ResetPasswordRequest request) {
        String hash = hash(request.token());
        Long userId = resets.findUserIdByTokenHash(hash).orElseThrow(this::invalid);
        var user = users.findForUpdate(userId).orElseThrow(this::invalid);
        var token = resets.findForUpdate(hash).orElseThrow(this::invalid);
        if (token.isUsed() || !token.getExpiresAt().isAfter(Instant.now())) throw invalid();
        user.setPasswordHash(passwords.encode(request.newPassword()));
        user.setCredentialVersion(Math.incrementExact(user.getCredentialVersion()));
        resets.findByUserIdAndUsedFalse(userId).forEach(value -> value.setUsed(true));
        refreshTokens.findByUserIdAndRevokedFalse(userId).forEach(value -> value.setRevoked(true));
    }

    private ApiException invalid() {
        return new ApiException(HttpStatus.BAD_REQUEST,
                "El código no es válido o caducó. Solicita otro correo de recuperación.");
    }

    private String hash(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 no disponible", exception);
        }
    }
}
