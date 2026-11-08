package com.smartfoodai.backend.meals.controller;

import com.smartfoodai.backend.meals.dto.PhotoAnalysisResponse;
import com.smartfoodai.backend.meals.dto.ResolvePhotoFoodRequest;
import com.smartfoodai.backend.meals.service.GeminiAnalysisService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/meals")
public class MealAnalysisController {
    private final GeminiAnalysisService analysis;
    private final com.smartfoodai.backend.meals.service.PhotoFoodResolver resolver;

    @PostMapping("/resolve-foods")
    public ResponseEntity<java.util.List<com.smartfoodai.backend.meals.service.PhotoFoodResolver.Resolution>> resolve(
            @AuthenticationPrincipal Long userId,
            @RequestBody @jakarta.validation.constraints.NotEmpty @jakarta.validation.constraints.Size(max = 20) java.util.List<@jakarta.validation.constraints.NotNull @jakarta.validation.Valid ResolvePhotoFoodRequest> request) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(resolver.resolveAll(userId, request));
    }


    @PostMapping(value = "/analyze", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<PhotoAnalysisResponse> analyze(@AuthenticationPrincipal Long userId,
                                                        @RequestPart("image") MultipartFile image) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(analysis.analyze(userId, image));
    }
}
