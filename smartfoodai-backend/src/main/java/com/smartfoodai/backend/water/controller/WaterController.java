package com.smartfoodai.backend.water.controller;
import com.smartfoodai.backend.water.dto.*;
import com.smartfoodai.backend.water.service.WaterService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
@RestController @RequiredArgsConstructor @RequestMapping("/api/water")
public class WaterController {
    private final WaterService service;
    @GetMapping public WaterSummary get(@AuthenticationPrincipal Long userId,@RequestParam String timeZone) {return service.get(userId,timeZone);}
    @PostMapping public WaterSummary add(@AuthenticationPrincipal Long userId,@Valid @RequestBody WaterRequest request) {return service.add(userId,request);}
    @PutMapping("/goal") @ResponseStatus(org.springframework.http.HttpStatus.NO_CONTENT)
    public void goal(@AuthenticationPrincipal Long userId,@Valid @RequestBody WaterGoalRequest request) {service.goal(userId,request);}
}
