package com.smartfoodai.backend.foods.service;

import com.smartfoodai.backend.foods.entity.CustomFood;
import java.text.Normalizer;
import java.util.*;

/** Conservative name matching: preparation and recipe ingredients remain significant. */
public final class FoodNameMatcher {
    private FoodNameMatcher() {}
    private static final Map<String, String> ALIASES = Map.ofEntries(
        Map.entry("papas", "papa"), Map.entry("patata", "papa"), Map.entry("patatas", "papa"),
        Map.entry("potato", "papa"), Map.entry("potatoes", "papa"),
        Map.entry("broccoli", "brocoli"), Map.entry("rice", "arroz"), Map.entry("white", "blanco"),
        Map.entry("chicken", "pollo"), Map.entry("breast", "pechuga"), Map.entry("pechugas", "pechuga"),
        Map.entry("peas", "arveja"), Map.entry("arvejas", "arveja"), Map.entry("guisantes", "arveja"),
        Map.entry("cocida", "cocido"), Map.entry("cocidas", "cocido"), Map.entry("cocidos", "cocido"),
        Map.entry("cooked", "cocido"), Map.entry("boiled", "hervido"), Map.entry("sancochada", "hervido"),
        Map.entry("sancochadas", "hervido"), Map.entry("hervida", "hervido"),
        Map.entry("raw", "crudo"), Map.entry("cruda", "crudo"),
        Map.entry("grilled", "plancha"), Map.entry("frita", "frito"), Map.entry("fried", "frito"),
        Map.entry("steamed", "vapor"));
    public static Set<String> tokens(String name) {
        String normalized = Normalizer.normalize(name.toLowerCase(Locale.ROOT), Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "");
        var result = new HashSet<String>();
        for (String token : normalized.split("[^a-z0-9]+")) {
            if (token.isBlank() || Set.of("de", "del", "la", "el", "a", "al", "the", "of").contains(token)) continue;
            result.add(ALIASES.getOrDefault(token, token));
        }
        return result;
    }
    public static List<CustomFood> exact(List<CustomFood> foods, String name) {
        var expected = tokens(name);
        return foods.stream().filter(food -> tokens(food.getName()).equals(expected)).toList();
    }
    public static List<CustomFood> candidates(List<CustomFood> foods, String name, String english) {
        var expected = tokens(name);
        if (english != null) expected.addAll(tokens(english));
        var preparation = Set.of("cocido", "crudo", "hervido", "plancha", "frito", "vapor", "blanco");
        expected.removeAll(preparation);
        if (expected.isEmpty()) return List.of();
        return foods.stream().filter(food -> tokens(food.getName()).stream().anyMatch(expected::contains))
            .sorted(Comparator.<CustomFood>comparingInt(food -> {
                var words = tokens(food.getName()); words.retainAll(expected); return words.size();
            }).reversed().thenComparing(CustomFood::getId)).limit(20).toList();
    }
}
