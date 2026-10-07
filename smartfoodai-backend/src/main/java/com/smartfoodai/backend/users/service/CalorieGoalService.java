package com.smartfoodai.backend.users.service;

import com.smartfoodai.backend.auth.entity.Sex;
import com.smartfoodai.backend.users.dto.CalorieSuggestionResponse;
import com.smartfoodai.backend.users.dto.MacroTargets;
import com.smartfoodai.backend.users.dto.ProfileData;
import java.math.BigDecimal;
import java.math.RoundingMode;
import org.springframework.stereotype.Service;

@Service
public class CalorieGoalService {
    public CalorieSuggestionResponse suggest(ProfileData profile) {
        if (profile.sex() == Sex.OTHER) {
            return new CalorieSuggestionResponse(false, null,
                    "Define una meta manual: no inferimos el parámetro requerido por la fórmula.");
        }
        BigDecimal basal = profile.weightKg().multiply(new BigDecimal("10"))
                .add(profile.heightCm().multiply(new BigDecimal("6.25")))
                .subtract(BigDecimal.valueOf(profile.age()).multiply(new BigDecimal("5")))
                .add(BigDecimal.valueOf(profile.sex() == Sex.M ? 5 : -161));
        BigDecimal activity = switch (profile.activityLevel()) {
            case sedentary -> new BigDecimal("1.2");
            case light -> new BigDecimal("1.375");
            case moderate -> new BigDecimal("1.55");
            case active -> new BigDecimal("1.725");
            case very_active -> new BigDecimal("1.9");
        };
        BigDecimal adjustment = switch (profile.goal()) {
            case lose -> new BigDecimal("0.9");
            case gain -> new BigDecimal("1.1");
            case maintain, improve_habits -> BigDecimal.ONE;
        };
        int calories = basal.multiply(activity).multiply(adjustment)
                .setScale(0, RoundingMode.HALF_UP).intValueExact();
        if (calories <= 0) {
            return new CalorieSuggestionResponse(false, null,
                    "No se pudo obtener una sugerencia positiva. Revisa tus datos o define una meta manual.");
        }
        return new CalorieSuggestionResponse(true, calories,
                "Estimación general editable; no reemplaza la orientación de un profesional de salud.");
    }

    public MacroTargets macros(int calories) {
        BigDecimal energy = BigDecimal.valueOf(calories);
        return new MacroTargets(
                energy.multiply(new BigDecimal("0.50")).divide(new BigDecimal("4"), 2, RoundingMode.HALF_UP),
                energy.multiply(new BigDecimal("0.20")).divide(new BigDecimal("4"), 2, RoundingMode.HALF_UP),
                energy.multiply(new BigDecimal("0.30")).divide(new BigDecimal("9"), 2, RoundingMode.HALF_UP));
    }
}
