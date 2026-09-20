package com.smartfoodai.backend.auth.service;

import com.smartfoodai.backend.auth.dto.*;
import com.smartfoodai.backend.auth.entity.RefreshToken;
import com.smartfoodai.backend.auth.entity.User;
import com.smartfoodai.backend.auth.repository.*;
import com.smartfoodai.backend.common.exception.ApiException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Locale;

@Service
public class AuthService {
    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final PasswordEncoder passwords;
    private final JwtService jwt;
    private final long refreshDays;
    private final SecureRandom random = new SecureRandom();
    private final String dummyHash;

    public AuthService(UserRepository users, RefreshTokenRepository refreshTokens,
                       PasswordEncoder passwords, JwtService jwt,
                       @Value("${app.jwt.refresh-token-days:30}") long refreshDays) {
        if (refreshDays <= 0 || refreshDays > 30)
            throw new IllegalArgumentException("El refresh token debe durar entre 1 y 30 días");
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.passwords = passwords;
        this.jwt = jwt;
        this.refreshDays = refreshDays;
        this.dummyHash = passwords.encode("synthetic-password-for-timing-only");
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        String email = normalizeEmail(request.email());
        if (users.existsByEmailIgnoreCase(email))
            throw new ApiException(HttpStatus.CONFLICT, "El correo ya está registrado");
        User user = users.saveAndFlush(User.builder().email(email)
                .passwordHash(passwords.encode(request.password())).build());
        return createSession(user.getId(), Instant.now().plus(refreshDays, ChronoUnit.DAYS));
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        User user = users.findByEmailIgnoreCase(normalizeEmail(request.email())).orElse(null);
        boolean matches = passwords.matches(request.password(), user == null ? dummyHash : user.getPasswordHash());
        if (user == null || !matches)
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Correo o contraseña incorrectos");
        return createSession(user.getId(), Instant.now().plus(refreshDays, ChronoUnit.DAYS));
    }

    @Transactional
    public AuthResponse refresh(String rawToken) {
        RefreshToken old = refreshTokens.findForUpdate(hash(rawToken))
                .orElseThrow(this::invalidSession);
        if (old.isRevoked() || !old.getExpiresAt().isAfter(Instant.now()) || !users.existsById(old.getUserId()))
            throw invalidSession();
        old.setRevoked(true);
        refreshTokens.save(old);
        // Rotation keeps the original absolute expiration; it never extends the session.
        return createSession(old.getUserId(), old.getExpiresAt());
    }

    @Transactional
    public void logout(String rawToken) {
        // An unknown/already revoked token also leaves no active session to revoke.
        refreshTokens.findForUpdate(hash(rawToken)).ifPresent(token -> {
            token.setRevoked(true);
            refreshTokens.save(token);
        });
    }

    @Transactional(readOnly = true)
    public UserResponse currentUser(Long userId) {
        User user = users.findById(userId).orElseThrow(this::invalidSession);
        return new UserResponse(user.getId(), user.getEmail());
    }

    private AuthResponse createSession(Long userId, Instant expiration) {
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        String rawToken = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        refreshTokens.save(RefreshToken.builder().userId(userId).tokenHash(hash(rawToken))
                .expiresAt(expiration).revoked(false).build());
        return new AuthResponse(jwt.createAccessToken(userId), rawToken, jwt.getExpiresIn());
    }

    private String normalizeEmail(String email) { return email.strip().toLowerCase(Locale.ROOT); }

    private ApiException invalidSession() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "La sesión no es válida; inicia sesión nuevamente");
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
