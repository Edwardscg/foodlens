package com.smartfoodai.backend.meals.repository;

import com.smartfoodai.backend.meals.entity.Meal;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
import java.time.Instant;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

public interface MealRepository extends JpaRepository<Meal, Long> {
    Page<Meal> findByUserIdAndConsumedAtGreaterThanEqualAndConsumedAtLessThan(
            Long userId, Instant start, Instant end, Pageable pageable);
    Optional<Meal> findByIdAndUserId(Long id, Long userId);
}
