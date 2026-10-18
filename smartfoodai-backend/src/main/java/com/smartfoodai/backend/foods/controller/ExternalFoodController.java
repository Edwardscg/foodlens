package com.smartfoodai.backend.foods.controller;

import com.smartfoodai.backend.foods.dto.*;
import com.smartfoodai.backend.foods.service.CustomFoodService;
import jakarta.validation.Valid;
import java.net.URI;
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
    private final CustomFoodService foods;

    @GetMapping
    public ResponseEntity<ExternalFoodPage> search(@AuthenticationPrincipal Long userId,
            @RequestParam String query, @RequestParam(defaultValue = "0") int page) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(service.search(userId, query, page));
    }
    @GetMapping("/{id}")
    public ResponseEntity<ExternalFoodDetail> detail(@AuthenticationPrincipal Long userId, @PathVariable long id) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(service.detail(userId, id));
    }

    @PostMapping("/{id}/import")
    public ResponseEntity<CustomFoodResponse> importFood(@AuthenticationPrincipal Long userId,
            @PathVariable long id, @Valid @RequestBody ImportExternalFoodRequest request) {
        // Fetch outside the database transaction; do not trust nutrients sent by clients.
        var source = service.detail(userId, id);
        var result = foods.importExternal(userId, request.name(), source);
        return ResponseEntity.created(URI.create("/api/foods/custom/" + result.id()))
                .cacheControl(CacheControl.noStore()).body(result);
    }
}
