package com.smartfoodai.backend.auth.service;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;

@Service
public class JwtService {
    private static final String ISSUER = "smartfoodai-backend";
    private final SecretKey key;
    private final long expiresIn;

    public JwtService(@Value("${app.jwt.secret}") String secret,
                      @Value("${app.jwt.access-token-minutes:20}") long minutes) {
        if (minutes <= 0) throw new IllegalArgumentException("La duración del access token debe ser positiva");
        if (secret.getBytes(StandardCharsets.UTF_8).length < 32)
            throw new IllegalArgumentException("JWT_SECRET debe contener al menos 32 bytes UTF-8 aleatorios");
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expiresIn = Math.multiplyExact(minutes, 60L);
    }

    public String createAccessToken(Long userId) {
        Instant now = Instant.now();
        return Jwts.builder().issuer(ISSUER).subject(userId.toString())
                .issuedAt(Date.from(now)).expiration(Date.from(now.plusSeconds(expiresIn)))
                .signWith(key, Jwts.SIG.HS256).compact();
    }

    public Long readUserId(String token) {
        var claims = Jwts.parser().verifyWith(key).requireIssuer(ISSUER).build()
                .parseSignedClaims(token).getPayload();
        if (claims.getExpiration() == null) throw new IllegalArgumentException("Token sin expiración");
        long userId = Long.parseLong(claims.getSubject());
        if (userId <= 0) throw new IllegalArgumentException("Usuario no válido");
        return userId;
    }

    public long getExpiresIn() { return expiresIn; }
}
