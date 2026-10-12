package com.smartfoodai.backend.meals.service;

import com.smartfoodai.backend.common.exception.ApiException;
import com.smartfoodai.backend.meals.dto.CreateMealRequest;
import com.smartfoodai.backend.meals.dto.MealResponse;
import com.smartfoodai.backend.meals.entity.MealPhoto;
import com.smartfoodai.backend.meals.repository.MealPhotoRepository;
import com.smartfoodai.backend.meals.repository.MealRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
@RequiredArgsConstructor
public class PhotoMealService {
    private final MealService meals;
    private final MealRepository repository;
    private final MealPhotoRepository photos;
    private final MealImageSanitizer images;

    @Transactional
    public MealResponse create(Long userId, CreateMealRequest request, MultipartFile image) {
        requireUser(userId);
        byte[] clean = images.sanitize(image);
        // Reuse ownership checks and server-side nutritional snapshots.
        var result = meals.create(userId, request);
        var meal = repository.findByIdAndUserId(result.id(), userId).orElseThrow();
        meal.setOrigin("PHOTO");
        var photo = new MealPhoto();
        photo.setMeal(meal);
        photo.setImage(clean);
        photos.saveAndFlush(photo);
        return meals.get(userId, result.id());
    }

    @Transactional(readOnly = true)
    public byte[] get(Long userId, Long mealId) {
        requireUser(userId);
        return photos.findByMealIdAndMealUserId(mealId, userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Foto no disponible."))
                .getImage();
    }

    private void requireUser(Long userId) {
        if (userId == null) throw new ApiException(HttpStatus.UNAUTHORIZED, "Inicia sesión para continuar.");
    }
}
