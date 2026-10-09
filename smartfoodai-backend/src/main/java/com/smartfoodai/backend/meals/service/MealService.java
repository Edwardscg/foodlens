package com.smartfoodai.backend.meals.service;

import com.smartfoodai.backend.common.exception.ApiException;
import com.smartfoodai.backend.foods.entity.CustomFood;
import com.smartfoodai.backend.foods.entity.NutritionBasis;
import com.smartfoodai.backend.foods.repository.CustomFoodRepository;
import com.smartfoodai.backend.meals.dto.CreateMealRequest;
import com.smartfoodai.backend.meals.dto.MealPage;
import com.smartfoodai.backend.meals.dto.UpdateMealRequest;
import java.util.HashMap;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import java.time.Duration;
import com.smartfoodai.backend.meals.dto.MealResponse;
import com.smartfoodai.backend.meals.dto.MealResponse.Nutrition;
import com.smartfoodai.backend.meals.entity.*;
import com.smartfoodai.backend.meals.repository.MealRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;

@Service
@RequiredArgsConstructor
public class MealService {
    private final MealRepository meals;
    private final CustomFoodRepository foods;

    @Transactional
    public MealResponse create(Long userId, CreateMealRequest request) {
        validateDate(request.consumedAt(), request.timeZone());
        Meal meal = new Meal();
        meal.setUserId(userId);
        meal.setMealType(request.mealType());
        meal.setConsumedAt(request.consumedAt());
        meal.setTimeZone(request.timeZone());
        for (CreateMealRequest.Item input : request.items()) {
            MealItem item = newItem(userId, meal, input);
            meal.getItems().add(item);
        }
        return response(meals.save(meal));
    }

    @Transactional(readOnly = true)
    public MealResponse get(Long userId, Long id) {
        return response(meals.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Comida no disponible.")));
    }

    @Transactional(readOnly = true)
    public MealPage list(Long userId, Instant start, Instant end, int page, int size) {
        if (userId == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Inicia sesión para continuar.");
        }
        // El fin es exclusivo. El margen de 32 días admite meses con cambios de horario.
        if (start == null || end == null || !start.isBefore(end)
                || Duration.between(start, end).compareTo(Duration.ofDays(32)) > 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Selecciona un periodo válido de hasta 31 días.");
        }
        if (page < 0 || size < 1 || size > 20 || (long) page * size > Integer.MAX_VALUE) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "La página o el tamaño no son válidos.");
        }
        var result = meals.findByUserIdAndConsumedAtGreaterThanEqualAndConsumedAtLessThan(
                userId, start, end, PageRequest.of(page, size,
                        Sort.by(Sort.Direction.DESC, "consumedAt", "id")));
        return new MealPage(result.getContent().stream().map(this::response).toList(),
                result.getNumber(), result.getSize(), result.getTotalElements(), result.getTotalPages());
    }

    @Transactional
    public void delete(Long userId, Long id) {
        if (userId == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Inicia sesión para continuar.");
        }
        Meal meal = meals.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Comida no disponible."));
        // Cascade elimina únicamente los elementos guardados de esta comida.
        meals.delete(meal);
    }

    @Transactional
    public MealResponse update(Long userId, Long id, UpdateMealRequest request) {
        if (userId == null) throw new ApiException(HttpStatus.UNAUTHORIZED, "Inicia sesión para continuar.");
        Meal meal = meals.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Comida no disponible."));
        if (meal.getVersion() != request.version()) {
            throw new ApiException(HttpStatus.CONFLICT, "La comida cambió. Recarga el detalle antes de editarla nuevamente.");
        }
        var quantities = new HashMap<Long, BigDecimal>();
        for (var item : request.items()) {
            if (quantities.put(item.id(), item.quantity()) != null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "No repitas alimentos del registro.");
            }
        }
        var currentIds = meal.getItems().stream().map(MealItem::getId).collect(java.util.stream.Collectors.toSet());
        if (!currentIds.containsAll(quantities.keySet())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Un alimento no pertenece a esta comida.");
        }
        var additions = request.addedItems() == null ? List.<CreateMealRequest.Item>of() : request.addedItems();
        int count = quantities.size() + additions.size();
        if (count < 1 || count > 50) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "La comida debe tener entre 1 y 50 alimentos.");
        }
        if ((request.consumedAt() == null) != (request.timeZone() == null)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Indica fecha y zona horaria juntas.");
        }
        if (request.consumedAt() != null) validateDate(request.consumedAt(), request.timeZone());
        var newItems = additions.stream().map(input -> newItem(userId, meal, input)).toList();
        meal.getItems().removeIf(item -> !quantities.containsKey(item.getId()));
        meal.setMealType(request.mealType());
        if (request.consumedAt() != null) {
            meal.setConsumedAt(request.consumedAt());
            meal.setTimeZone(request.timeZone());
        }
        for (MealItem item : meal.getItems()) {
            item.setQuantity(quantities.get(item.getId()));
            BigDecimal factor = item.getUnit() == MealUnit.GRAMS
                    ? item.getQuantity().movePointLeft(2) : item.getQuantity();
            item.setCalories(scale(item.getBaseCalories(), factor));
            item.setProteinG(scale(item.getBaseProteinG(), factor));
            item.setCarbsG(scale(item.getBaseCarbsG(), factor));
            item.setFatG(scale(item.getBaseFatG(), factor));
        }
        meal.getItems().addAll(newItems);
        // Los cambios en hijos también deben incrementar la versión de la comida.
        meal.setUpdatedAt(Instant.now());
        return response(meals.saveAndFlush(meal));
    }

    private void validateDate(Instant consumedAt, String timeZone) {
        if (!ZoneId.getAvailableZoneIds().contains(timeZone)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Selecciona una zona horaria IANA válida.");
        }
        if (consumedAt.isBefore(Instant.parse("1000-01-01T00:00:00Z"))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "La fecha de consumo está fuera del rango admitido.");
        }
        if (consumedAt.isAfter(Instant.now())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "La fecha de consumo no puede estar en el futuro.");
        }
    }

    private MealItem newItem(Long userId, Meal meal, CreateMealRequest.Item input) {
        CustomFood food = foods.findByIdAndUserId(input.foodId(), userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Alimento no disponible."));
        MealUnit expected = food.getBasis() == NutritionBasis.PER_100_G
                ? MealUnit.GRAMS : MealUnit.SERVINGS;
        if (input.unit() != expected) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "La unidad debe coincidir con la base nutricional del alimento: " + expected);
        }
        MealItem item = new MealItem();
        item.setMeal(meal);
        item.setFoodId(food.getId());
        item.setName(food.getName());
        item.setBasis(food.getBasis());
        item.setQuantity(input.quantity());
        item.setUnit(input.unit());
        item.setBaseCalories(food.getCalories());
        item.setBaseProteinG(food.getProteinG());
        item.setBaseCarbsG(food.getCarbsG());
        item.setBaseFatG(food.getFatG());
        BigDecimal factor = expected == MealUnit.GRAMS
                ? input.quantity().movePointLeft(2) : input.quantity();
        item.setCalories(scale(food.getCalories(), factor));
        item.setProteinG(scale(food.getProteinG(), factor));
        item.setCarbsG(scale(food.getCarbsG(), factor));
        item.setFatG(scale(food.getFatG(), factor));
        return item;
    }

    @Transactional(readOnly = true)
    public com.smartfoodai.backend.meals.dto.MealSummary summary(Long userId, Instant start, Instant end) {
        if (userId == null) throw new ApiException(HttpStatus.UNAUTHORIZED, "Inicia sesión para continuar.");
        if (start == null || end == null || !start.isBefore(end)
                || Duration.between(start, end).compareTo(Duration.ofHours(25)) > 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Selecciona un día válido.");
        }
        return meals.summarize(userId, start, end);
    }

    private BigDecimal scale(BigDecimal value, BigDecimal factor) {
        return value.multiply(factor).setScale(2, RoundingMode.HALF_UP);
    }

    private MealResponse response(Meal meal) {
        List<MealResponse.Item> items = meal.getItems().stream().map(item -> new MealResponse.Item(
                item.getId(), item.getFoodId(), item.getName(), item.getBasis(), item.getQuantity(), item.getUnit(),
                new Nutrition(item.getBaseCalories(), item.getBaseProteinG(), item.getBaseCarbsG(), item.getBaseFatG()),
                new Nutrition(item.getCalories(), item.getProteinG(), item.getCarbsG(), item.getFatG()))).toList();
        BigDecimal calories = BigDecimal.ZERO, protein = BigDecimal.ZERO,
                carbs = BigDecimal.ZERO, fat = BigDecimal.ZERO;
        for (MealResponse.Item item : items) {
            calories = calories.add(item.consumedNutrition().calories());
            protein = protein.add(item.consumedNutrition().proteinG());
            carbs = carbs.add(item.consumedNutrition().carbsG());
            fat = fat.add(item.consumedNutrition().fatG());
        }
        return new MealResponse(meal.getId(), meal.getMealType(), meal.getConsumedAt(),
                meal.getTimeZone(), meal.getOrigin(), meal.getCreatedAt(), items,
                new Nutrition(calories, protein, carbs, fat), meal.getVersion());
    }
}
