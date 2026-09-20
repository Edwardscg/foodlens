package com.smartfoodai.backend.foods.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "custom_foods")
@NoArgsConstructor
@AllArgsConstructor
@Getter
@Setter
public class CustomFood {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "user_id", nullable = false, updatable = false)
    private Long userId;
    @Column(nullable = false, length = 120)
    private String name;
    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(nullable = false, length = 20)
    private NutritionBasis basis;
    @Column(nullable = false, precision = 9, scale = 2)
    private BigDecimal calories;
    @Column(name = "protein_g", nullable = false, precision = 9, scale = 2)
    private BigDecimal proteinG;
    @Column(name = "carbs_g", nullable = false, precision = 9, scale = 2)
    private BigDecimal carbsG;
    @Column(name = "fat_g", nullable = false, precision = 9, scale = 2)
    private BigDecimal fatG;
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() { createdAt = Instant.now(); }
}
