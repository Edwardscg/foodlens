package com.smartfoodai.backend.meals.entity;

import com.smartfoodai.backend.foods.entity.NutritionBasis;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import java.math.BigDecimal;

@Entity
@Table(name = "meal_items")
@Getter @Setter @NoArgsConstructor
public class MealItem {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "meal_id", nullable = false)
    private Meal meal;
    // Identificador de referencia sin FK: el snapshot sobrevive al retiro del alimento.
    @Column(name = "food_id", nullable = false)
    private Long foodId;
    @Column(nullable = false, length = 120)
    private String name;
    @Enumerated(EnumType.STRING) @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(nullable = false, length = 20)
    private NutritionBasis basis;
    @Column(nullable = false, precision = 7, scale = 2)
    private BigDecimal quantity;
    @Enumerated(EnumType.STRING) @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(nullable = false, length = 20)
    private MealUnit unit;
    @Column(name = "base_calories", nullable = false, precision = 15, scale = 2)
    private BigDecimal baseCalories;
    @Column(name = "base_protein_g", nullable = false, precision = 15, scale = 2)
    private BigDecimal baseProteinG;
    @Column(name = "base_carbs_g", nullable = false, precision = 15, scale = 2)
    private BigDecimal baseCarbsG;
    @Column(name = "base_fat_g", nullable = false, precision = 15, scale = 2)
    private BigDecimal baseFatG;
    @Column(name = "calories", nullable = false, precision = 15, scale = 2)
    private BigDecimal calories;
    @Column(name = "protein_g", nullable = false, precision = 15, scale = 2)
    private BigDecimal proteinG;
    @Column(name = "carbs_g", nullable = false, precision = 15, scale = 2)
    private BigDecimal carbsG;
    @Column(name = "fat_g", nullable = false, precision = 15, scale = 2)
    private BigDecimal fatG;
}
