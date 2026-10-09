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
    @org.springframework.data.jpa.repository.Query("""
        select new com.smartfoodai.backend.meals.dto.MealSummary(
            count(distinct m.id), coalesce(sum(i.calories), 0),
            coalesce(sum(i.proteinG), 0), coalesce(sum(i.carbsG), 0), coalesce(sum(i.fatG), 0))
        from Meal m left join m.items i
        where m.userId = :userId and m.consumedAt >= :start and m.consumedAt < :end
        """)
    com.smartfoodai.backend.meals.dto.MealSummary summarize(Long userId, Instant start, Instant end);
    Optional<Meal> findByIdAndUserId(Long id, Long userId);
}
