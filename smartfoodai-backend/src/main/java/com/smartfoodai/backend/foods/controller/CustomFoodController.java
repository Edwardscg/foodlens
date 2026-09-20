package com.smartfoodai.backend.foods.controller;

import com.smartfoodai.backend.foods.dto.*;
import com.smartfoodai.backend.foods.service.CustomFoodService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/foods/custom")
public class CustomFoodController {
    private final CustomFoodService foods;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CustomFoodResponse create(@AuthenticationPrincipal Long userId,
                                     @Valid @RequestBody CreateCustomFoodRequest request) {
        return foods.create(userId, request);
    }

    @GetMapping
    public CustomFoodPage list(@AuthenticationPrincipal Long userId,
                               @RequestParam(name = "page", defaultValue = "0") int page,
                               @RequestParam(name = "size", defaultValue = "20") int size) {
        return foods.list(userId, page, size);
    }
}
