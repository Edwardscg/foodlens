package com.smartfoodai.backend.meals.service;

import com.smartfoodai.backend.common.exception.ApiException;
import com.smartfoodai.backend.foods.dto.CustomFoodResponse;
import com.smartfoodai.backend.foods.entity.NutritionBasis;
import com.smartfoodai.backend.foods.repository.CustomFoodRepository;
import com.smartfoodai.backend.foods.service.UsdaFoodService;
import com.smartfoodai.backend.meals.dto.ResolvePhotoFoodRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import java.util.*;
import com.smartfoodai.backend.foods.service.FoodNameMatcher;
import com.smartfoodai.backend.foods.entity.CustomFood;
import com.smartfoodai.backend.foods.dto.ExternalFoodPage;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import java.util.concurrent.TimeUnit;

@Service
@RequiredArgsConstructor
public class PhotoFoodResolver {
    private final CustomFoodRepository foods;
    private final UsdaFoodService usda;
    private final GeminiAnalysisService matcher;

    public record Resolution(CustomFoodResponse food, Long externalFdcId, String sourceName, String issue) {}
    private Resolution unresolved(String issue) { return new Resolution(null, null, null, issue); }

    public List<Resolution> resolveAll(Long userId, List<ResolvePhotoFoodRequest> requests) {
        if (userId == null) throw new ApiException(HttpStatus.UNAUTHORIZED, "Inicia sesión para continuar.");
        if (requests == null || requests.isEmpty() || requests.size() > 20) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Revisa entre 1 y 20 alimentos.");
        }
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(75);
        var catalog = new ArrayList<CustomFood>();
        int page = 0;
        org.springframework.data.domain.Page<CustomFood> batch;
        do {
            batch = foods.findByUserId(userId, PageRequest.of(page++, 200, Sort.by("id")));
            catalog.addAll(batch.getContent());
        } while (batch.hasNext());
        var privateGroups = new ArrayList<GeminiAnalysisService.MatchRequest>();
        for (int i = 0; i < requests.size(); i++) {
            var request = requests.get(i);
            if (!FoodNameMatcher.exact(catalog, request.name()).isEmpty()) continue;
            var options = FoodNameMatcher.candidates(catalog, request.name(), request.nutritionQuery());
            if (!options.isEmpty()) privateGroups.add(new GeminiAnalysisService.MatchRequest(i, request.name(),
                request.nutritionQuery() == null ? request.name() : request.nutritionQuery(),
                options.stream().map(food -> new ExternalFoodPage.Item(food.getId(), food.getName(), "USER_PRIVATE")).toList()));
        }
        Map<Integer, Long> privateMatches;
        try { privateMatches = matcher.matchNutrition(privateGroups); }
        catch (ApiException exception) { privateMatches = Map.of(); }
        var result = new ArrayList<Resolution>();
        var groups = new ArrayList<GeminiAnalysisService.MatchRequest>();
        for (int i = 0; i < requests.size(); i++) {
            var request = requests.get(i);
            result.add(unresolved("No encontramos una coincidencia nutricional completa. Puedes elegir o crear el alimento."));
            var own = FoodNameMatcher.exact(catalog, request.name());
            if (own.isEmpty() && privateMatches.containsKey(i)) {
                Long selectedId = privateMatches.get(i);
                own = catalog.stream().filter(food -> food.getId().equals(selectedId)).toList();
            }
            if (own.size() > 1) continue;
            if (own.size() == 1) {
                var food = own.getFirst();
                result.set(i, new Resolution(new CustomFoodResponse(food.getId(), food.getName(), food.getBasis(),
                        food.getCalories(), food.getProteinG(), food.getCarbsG(), food.getFatG(),
                        food.getCreatedAt(), food.getSourceFdcId(), food.getSourceImportedAt()), null, "Mis alimentos", null));
                continue;
            }
            String query = request.nutritionQuery();
            if (query == null || query.isBlank()) continue;
            if (System.nanoTime() >= deadline) {
                result.set(i, unresolved("La búsqueda tardó demasiado. Puedes elegir el alimento manualmente.")); continue;
            }
            try {
                var candidates = usda.search(userId, query, 0).items();
                if (!candidates.isEmpty()) groups.add(new GeminiAnalysisService.MatchRequest(i, request.name(), query, candidates));
            } catch (ApiException exception) {
                result.set(i, unresolved("No pudimos consultar USDA. Puedes elegir el alimento manualmente."));
            }
        }
        Map<Integer, Long> matched;
        try { matched = matcher.matchNutrition(groups); }
        catch (ApiException exception) {
            for (var group : groups) result.set(group.index(), unresolved("La vinculación automática no está disponible por ahora. Puedes elegir el alimento manualmente."));
            return List.copyOf(result);
        }
        for (var entry : matched.entrySet()) {
            int index = entry.getKey();
            if (System.nanoTime() >= deadline) {
                result.set(index, unresolved("La consulta tardó demasiado. Puedes elegir el alimento manualmente.")); continue;
            }
            try {
                var detail = usda.detail(userId, entry.getValue());
                if (!detail.complete()) continue;
                // Draft only. Confirmation imports and snapshots it in the meal transaction.
                result.set(index, new Resolution(new CustomFoodResponse(detail.fdcId(), requests.get(index).name().strip(),
                        NutritionBasis.PER_100_G, detail.calories(), detail.proteinG(), detail.carbsG(), detail.fatG(), null, null, null),
                        detail.fdcId(), detail.name(), null));
            } catch (ApiException exception) {
                result.set(index, unresolved("No pudimos cargar los nutrientes de USDA. Puedes elegir el alimento manualmente."));
            }
        }
        return List.copyOf(result);
    }
}
