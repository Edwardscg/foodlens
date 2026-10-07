package com.smartfoodai.backend.meals.controller;

import com.smartfoodai.backend.meals.dto.CreateMealRequest;
import com.smartfoodai.backend.meals.dto.MealResponse;
import com.smartfoodai.backend.meals.service.MealService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import java.net.URI;
import java.time.Instant;
import com.smartfoodai.backend.meals.dto.MealPage;

@RestController
@RequestMapping("/api/meals")
@RequiredArgsConstructor
public class MealController {
    private final MealService service;
    @PostMapping
    public ResponseEntity<MealResponse> create(@AuthenticationPrincipal Long userId,
                                               @Valid @RequestBody CreateMealRequest request) {
        MealResponse result = service.create(userId, request);
        return ResponseEntity.created(URI.create("/api/meals/" + result.id())).body(result);
    }
    @GetMapping
    public MealPage list(@AuthenticationPrincipal Long userId,
                         @RequestParam Instant start, @RequestParam Instant end,
                         @RequestParam(defaultValue = "0") int page,
                         @RequestParam(defaultValue = "20") int size) {
        return service.list(userId, start, end, page, size);
    }
    @GetMapping("/{id}")
    public MealResponse get(@AuthenticationPrincipal Long userId, @PathVariable Long id) {
        return service.get(userId, id);
    }
}
