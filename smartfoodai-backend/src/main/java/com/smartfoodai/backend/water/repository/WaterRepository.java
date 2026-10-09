package com.smartfoodai.backend.water.repository;
import com.smartfoodai.backend.water.entity.WaterEntry;
import org.springframework.data.jpa.repository.*;
import java.time.Instant;
import java.util.Optional;
public interface WaterRepository extends JpaRepository<WaterEntry,Long> {
    Optional<WaterEntry> findByUserIdAndRequestId(Long userId,String requestId);
    @Query("select coalesce(sum(w.amount),0) from WaterEntry w where w.userId=:userId and w.recordedAt>=:start and w.recordedAt<:end")
    Long sum(Long userId,Instant start,Instant end);
}
