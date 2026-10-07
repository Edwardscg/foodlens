package com.smartfoodai.backend.meals.repository;

import com.smartfoodai.backend.meals.entity.Meal;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface MealRepository extends JpaRepository<Meal, Long> {
    Optional<Meal> findByIdAndUserId(Long id, Long userId);
}
