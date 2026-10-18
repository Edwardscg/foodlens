package com.smartfoodai.backend.foods.controller;

import com.smartfoodai.backend.foods.dto.ExternalFoodPage;
import com.smartfoodai.backend.foods.service.UsdaFoodService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/foods/external")
@RequiredArgsConstructor
public class ExternalFoodController {
    private final UsdaFoodService service;

    @GetMapping
    public ResponseEntity<ExternalFoodPage> search(@AuthenticationPrincipal Long userId,
            @RequestParam String query, @RequestParam(defaultValue = "0") int page) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(service.search(userId, query, page));
    }
}
