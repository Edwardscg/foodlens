package com.smartfoodai.backend.meals.controller;

import com.smartfoodai.backend.meals.dto.CreateMealRequest;
import com.smartfoodai.backend.meals.dto.MealResponse;
import com.smartfoodai.backend.meals.service.PhotoMealService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import java.net.URI;

@RestController
@RequestMapping("/api/meals")
@RequiredArgsConstructor
public class PhotoMealController {
    private final PhotoMealService service;

    @PostMapping(value = "/photo", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<MealResponse> create(@AuthenticationPrincipal Long userId,
            @Valid @RequestPart("meal") CreateMealRequest request,
            @RequestPart("image") MultipartFile image) {
        var result = service.create(userId, request, image);
        return ResponseEntity.created(URI.create("/api/meals/" + result.id()))
                .cacheControl(CacheControl.noStore()).body(result);
    }

    @GetMapping(value = "/{id}/photo", produces = MediaType.IMAGE_JPEG_VALUE)
    public ResponseEntity<byte[]> get(@AuthenticationPrincipal Long userId, @PathVariable Long id) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
                .header("Content-Disposition", "inline; filename=meal.jpg")
                .body(service.get(userId, id));
    }
}
