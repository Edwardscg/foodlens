package com.smartfoodai.backend.meals.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

@Entity
@Table(name = "meal_photos")
@Getter @Setter @NoArgsConstructor
public class MealPhoto {
    @Id
    @Column(name = "meal_id")
    private Long mealId;
    @MapsId
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "meal_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private Meal meal;
    @Lob
    @Column(nullable = false, columnDefinition = "LONGBLOB")
    private byte[] image;
}
