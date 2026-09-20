package com.smartfoodai.backend.foods.repository;

import com.smartfoodai.backend.foods.entity.CustomFood;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CustomFoodRepository extends JpaRepository<CustomFood, Long> {
    Page<CustomFood> findByUserId(Long userId, Pageable pageable);
}
