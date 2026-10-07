package com.smartfoodai.backend.meals.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "meals")
@Getter @Setter @NoArgsConstructor
public class Meal {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "user_id", nullable = false, updatable = false)
    private Long userId;
    @Enumerated(EnumType.STRING) @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(name = "meal_type", nullable = false, length = 20)
    private MealType mealType;
    @Column(name = "consumed_at", nullable = false)
    private Instant consumedAt;
    @Column(name = "time_zone", nullable = false, length = 64)
    private String timeZone;
    @Column(nullable = false, length = 20)
    private String origin = "MANUAL";
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
    @OneToMany(mappedBy = "meal", cascade = CascadeType.ALL)
    @OrderBy("id ASC")
    private List<MealItem> items = new ArrayList<>();
    @PrePersist
    void onCreate() { createdAt = Instant.now(); }
}
