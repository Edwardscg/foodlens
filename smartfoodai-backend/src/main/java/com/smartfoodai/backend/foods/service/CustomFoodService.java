package com.smartfoodai.backend.foods.service;

import com.smartfoodai.backend.common.exception.ApiException;
import com.smartfoodai.backend.foods.dto.*;
import com.smartfoodai.backend.foods.entity.CustomFood;
import com.smartfoodai.backend.foods.repository.CustomFoodRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CustomFoodService {
    private final CustomFoodRepository foods;

    @Transactional
    public CustomFoodResponse create(Long userId, CreateCustomFoodRequest request) {
        requireUser(userId);
        var food = new CustomFood();
        food.setUserId(userId);
        food.setName(request.name().strip());
        food.setBasis(request.basis());
        food.setCalories(request.calories());
        food.setProteinG(request.proteinG());
        food.setCarbsG(request.carbsG());
        food.setFatG(request.fatG());
        return response(foods.save(food));
    }

    @Transactional(readOnly = true)
    public CustomFoodPage list(Long userId, int page, int size) {
        requireUser(userId);
        if (page < 0 || size < 1 || size > 50 || (long) page * size > Integer.MAX_VALUE) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "La página debe ser 0 o mayor y el tamaño debe estar entre 1 y 50");
        }
        var result = foods.findByUserId(userId, PageRequest.of(page, size,
                Sort.by(Sort.Direction.DESC, "createdAt", "id")));
        return new CustomFoodPage(result.getContent().stream().map(this::response).toList(),
                result.getNumber(), result.getSize(), result.getTotalElements(), result.getTotalPages());
    }

    private void requireUser(Long userId) {
        if (userId == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Inicia sesión para continuar");
        }
    }

    private CustomFoodResponse response(CustomFood food) {
        return new CustomFoodResponse(food.getId(), food.getName(), food.getBasis(),
                food.getCalories(), food.getProteinG(), food.getCarbsG(), food.getFatG(), food.getCreatedAt());
    }
}
