package com.smartfoodai.backend.water.service;
import com.smartfoodai.backend.water.dto.*;
import com.smartfoodai.backend.water.entity.WaterEntry;
import com.smartfoodai.backend.water.repository.WaterRepository;
import com.smartfoodai.backend.auth.entity.User;
import com.smartfoodai.backend.auth.repository.UserRepository;
import com.smartfoodai.backend.common.exception.ApiException;
import jakarta.persistence.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.HttpStatus;
import java.time.*;
import java.util.UUID;
@Service @RequiredArgsConstructor
public class WaterService {
    private final WaterRepository entries;
    private final UserRepository users;
    @PersistenceContext private EntityManager entityManager;
    private User user(Long id) {
        if(id==null) throw new ApiException(HttpStatus.UNAUTHORIZED,"Inicia sesión para continuar.");
        return users.findById(id).orElseThrow(()->new ApiException(HttpStatus.UNAUTHORIZED,"La cuenta no está disponible."));
    }
    private ZoneId zone(String name) {
        if(name==null || !ZoneId.getAvailableZoneIds().contains(name)) throw new ApiException(HttpStatus.BAD_REQUEST,"Selecciona una zona horaria válida.");
        return ZoneId.of(name);
    }
    private WaterSummary summary(User user,ZoneId zone) {
        var today=LocalDate.now(zone);
        return new WaterSummary(today,zone.getId(),entries.sum(user.getId(),today.atStartOfDay(zone).toInstant(),today.plusDays(1).atStartOfDay(zone).toInstant()),user.getDailyWaterGoalMl());
    }
    @Transactional(readOnly=true)
    public WaterSummary get(Long id,String timeZone) { return summary(user(id),zone(timeZone)); }
    @Transactional
    public WaterSummary add(Long id,WaterRequest request) {
        var zone=zone(request.timeZone());
        var user=user(id);
        // Serializa reenvíos de la misma cuenta antes de comprobar la clave única.
        entityManager.lock(user,LockModeType.PESSIMISTIC_WRITE);
        var key=UUID.fromString(request.requestId()).toString();
        var previous=entries.findByUserIdAndRequestId(id,key);
        if(previous.isPresent()) {
            if(!previous.get().getAmount().equals(request.amount()) || !previous.get().getTimeZone().equals(zone.getId()))
                throw new ApiException(HttpStatus.CONFLICT,"Este registro ya fue enviado con otros datos.");
        } else {
            var entry=new WaterEntry();entry.setUserId(id);entry.setRequestId(key);entry.setAmount(request.amount());
            entry.setTimeZone(zone.getId());entry.setRecordedAt(Instant.now());entries.saveAndFlush(entry);
        }
        return summary(user,zone);
    }
    @Transactional
    public void goal(Long id,WaterGoalRequest request) {
        var user=user(id);entityManager.lock(user,LockModeType.PESSIMISTIC_WRITE);
        user.setDailyWaterGoalMl(request.goalMl());users.save(user);
    }
}
