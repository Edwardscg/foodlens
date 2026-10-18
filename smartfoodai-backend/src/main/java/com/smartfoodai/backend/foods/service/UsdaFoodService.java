package com.smartfoodai.backend.foods.service;

import com.smartfoodai.backend.common.exception.ApiException;
import com.smartfoodai.backend.foods.dto.ExternalFoodPage;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import tools.jackson.databind.json.JsonMapper;
import java.net.URI;
import java.net.http.*;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;

@Service
@RequiredArgsConstructor
public class UsdaFoodService {
    private final JsonMapper json;
    @Value("${USDA_API_KEY:}") private String apiKey;
    private URI endpoint = URI.create("https://api.nal.usda.gov/fdc/v1/foods/search");
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5)).followRedirects(HttpClient.Redirect.NEVER).build();
    private final Semaphore slots = new Semaphore(2);
    private long windowStart = System.nanoTime();
    private int requests;

    public ExternalFoodPage search(Long userId, String query, int page) {
        if (userId == null) throw new ApiException(HttpStatus.UNAUTHORIZED, "Inicia sesión para continuar.");
        if (query == null || query.isBlank() || query.trim().length() > 120 || page < 0 || page > 999) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Ingresa una búsqueda de hasta 120 caracteres y una página válida.");
        }
        if (apiKey == null || apiKey.isBlank()) throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,
                "El catálogo USDA no está disponible. Puedes usar Mis alimentos.");
        if (!slots.tryAcquire()) throw busy();
        try {
            acquireQuota();
            var body = Map.of("query", query.trim(), "pageSize", 20, "pageNumber", page + 1,
                    "dataType", List.of("Foundation", "SR Legacy"));
            var request = HttpRequest.newBuilder(endpoint).timeout(Duration.ofSeconds(15))
                    .header("X-Api-Key", apiKey).header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body))).build();
            var pending = http.sendAsync(request, HttpResponse.BodyHandlers.ofString());
            try {
                var response = pending.get(15, TimeUnit.SECONDS);
                if (response.statusCode() == 429) throw busy();
                if (response.statusCode() != 200 || response.body().length() > 2_000_000) throw unavailable();
                return parse(response.body(), page);
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                throw unavailable();
            } catch (ApiException exception) { throw exception; }
            catch (Exception exception) { throw unavailable(); }
            finally { pending.cancel(true); }
        } finally { slots.release(); }
    }

    private synchronized void acquireQuota() {
        long now = System.nanoTime();
        if (now - windowStart >= Duration.ofHours(1).toNanos()) { windowStart = now; requests = 0; }
        if (requests >= 900) throw busy();
        requests++;
    }

    ExternalFoodPage parse(String body, int page) {
        try {
            var root = json.readTree(body);
            var foods = root.path("foods");
            var pages = root.path("totalPages");
            if (!foods.isArray() || foods.size() > 20 || !pages.isIntegralNumber()
                    || !pages.canConvertToInt() || pages.asInt() < 0) throw unavailable();
            var items = new ArrayList<ExternalFoodPage.Item>();
            var ids = new HashSet<Long>();
            for (var food : foods) {
                var id = food.path("fdcId");
                var name = food.path("description");
                var type = food.path("dataType");
                if (!id.isIntegralNumber() || !id.canConvertToLong() || id.asLong() <= 0
                        || !ids.add(id.asLong()) || !name.isString() || name.asText().isBlank()
                        || name.asText().length() > 1000 || !type.isString()
                        || !Set.of("Foundation", "SR Legacy").contains(type.asText())) throw unavailable();
                items.add(new ExternalFoodPage.Item(id.asLong(), name.asText().trim(), type.asText()));
            }
            return new ExternalFoodPage(List.copyOf(items), page, pages.asInt());
        } catch (ApiException exception) { throw exception; }
        catch (Exception exception) { throw unavailable(); }
    }

    private ApiException busy() { return new ApiException(HttpStatus.TOO_MANY_REQUESTS,
            "El catálogo está ocupado. Inténtalo más tarde o usa Mis alimentos."); }
    private ApiException unavailable() { return new ApiException(HttpStatus.BAD_GATEWAY,
            "No pudimos consultar USDA. Inténtalo más tarde o usa Mis alimentos."); }
}
