package com.smartfoodai.backend.users.controller;

import com.smartfoodai.backend.users.dto.*;
import com.smartfoodai.backend.users.service.CalorieGoalService;
import com.smartfoodai.backend.users.service.ProfileService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users/me/profile")
@RequiredArgsConstructor
public class ProfileController {
    private final ProfileService profiles;
    private final CalorieGoalService calories;

    @GetMapping
    public ProfileResponse get(@AuthenticationPrincipal Long userId) {
        return profiles.get(userId);
    }

    @PutMapping
    public ProfileResponse save(@AuthenticationPrincipal Long userId,
                                @Valid @RequestBody SaveProfileRequest request) {
        return profiles.save(userId, request);
    }

    @PostMapping("/calorie-suggestion")
    public CalorieSuggestionResponse suggest(@Valid @RequestBody ProfileData request) {
        return calories.suggest(request);
    }
}
