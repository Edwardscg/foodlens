package com.smartfoodai.backend.meals.repository;

import com.smartfoodai.backend.meals.entity.MealPhoto;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface MealPhotoRepository extends JpaRepository<MealPhoto, Long> {
    Optional<MealPhoto> findByMealIdAndMealUserId(Long mealId, Long userId);
}
