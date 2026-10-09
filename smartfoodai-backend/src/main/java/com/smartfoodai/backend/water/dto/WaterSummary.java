package com.smartfoodai.backend.water.dto;
import java.time.LocalDate;
public record WaterSummary(LocalDate date, String timeZone, Long consumedMl, Integer goalMl) {}
