package com.smartfoodai.backend.users.dto;

public record ProfileResponse(boolean completed, ProfileData profile,
                              Integer dailyCalorieGoal, CalorieGoalSource goalSource,
                              MacroTargets macroTargets) {}
