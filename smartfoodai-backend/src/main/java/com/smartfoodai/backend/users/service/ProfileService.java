package com.smartfoodai.backend.users.service;

import com.smartfoodai.backend.auth.entity.User;
import com.smartfoodai.backend.auth.repository.UserRepository;
import com.smartfoodai.backend.common.exception.ApiException;
import com.smartfoodai.backend.users.dto.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ProfileService {
    private final UserRepository users;
    private final CalorieGoalService calories;

    @Transactional(readOnly = true)
    public ProfileResponse get(Long userId) { return response(currentUser(userId)); }

    @Transactional
    public ProfileResponse save(Long userId, SaveProfileRequest request) {
        User user = currentUser(userId);
        ProfileData data = request.profile();
        int target;
        if (request.goalSource() == CalorieGoalSource.SUGGESTED) {
            if (request.dailyCalorieGoal() != null) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Para modificar la sugerencia selecciona MANUAL. Con SUGGESTED omite dailyCalorieGoal.");
            }
            var suggestion = calories.suggest(data);
            if (!suggestion.available()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, suggestion.message());
            }
            target = suggestion.calories();
        } else {
            if (request.dailyCalorieGoal() == null || request.dailyCalorieGoal() <= 0) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Ingresa una meta calórica manual mayor que cero.");
            }
            target = request.dailyCalorieGoal();
        }
        user.setName(data.name() == null || data.name().isBlank() ? null : data.name().strip());
        user.setDeclaredAge(data.age());
        user.setSex(data.sex());
        user.setWeightKg(data.weightKg());
        user.setHeightCm(data.heightCm());
        user.setActivityLevel(data.activityLevel());
        user.setGoal(data.goal());
        user.setDailyCalorieGoal(target);
        user.setCalorieGoalSource(request.goalSource().name());
        return response(users.save(user));
    }

    private User currentUser(Long userId) {
        if (userId == null) throw new ApiException(HttpStatus.UNAUTHORIZED, "Inicia sesión para continuar");
        return users.findById(userId).orElseThrow(() ->
                new ApiException(HttpStatus.UNAUTHORIZED, "La cuenta no está disponible"));
    }

    private ProfileResponse response(User user) {
        var data = new ProfileData(user.getName(), user.getDeclaredAge(), user.getSex(),
                user.getWeightKg(), user.getHeightCm(), user.getActivityLevel(), user.getGoal());
        CalorieGoalSource source = user.getCalorieGoalSource() == null ? null
                : CalorieGoalSource.valueOf(user.getCalorieGoalSource());
        Integer target = user.getDailyCalorieGoal();
        boolean complete = data.age() != null && data.sex() != null && data.weightKg() != null
                && data.heightCm() != null && data.activityLevel() != null && data.goal() != null
                && target != null && target > 0 && source != null;
        return new ProfileResponse(complete, data, target, source,
                target == null || target <= 0 ? null : calories.macros(target));
    }
}
