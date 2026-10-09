package com.smartfoodai.backend.auth.controller;

import com.smartfoodai.backend.auth.dto.*;
import com.smartfoodai.backend.auth.service.PasswordRecoveryService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/auth")
public class PasswordRecoveryController {
    private final PasswordRecoveryService recovery;

    @PostMapping("/forgot-password")
    public ResponseEntity<Void> request(@Valid @RequestBody ForgotPasswordRequest request) {
        recovery.request(request.email());
        return ResponseEntity.accepted().cacheControl(CacheControl.noStore()).build();
    }

    @PostMapping("/reset-password")
    public ResponseEntity<Void> reset(@Valid @RequestBody ResetPasswordRequest request) {
        recovery.reset(request);
        return ResponseEntity.noContent().cacheControl(CacheControl.noStore()).build();
    }
}
