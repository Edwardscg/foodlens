package com.smartfoodai.backend.water.entity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import lombok.NoArgsConstructor;
import java.time.Instant;
@Entity
@Table(name="water_entries", uniqueConstraints=@UniqueConstraint(columnNames={"user_id","request_id"}))
@Getter @Setter @NoArgsConstructor
public class WaterEntry {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @Column(name="user_id",nullable=false) private Long userId;
    @Column(name="request_id",nullable=false,length=36) private String requestId;
    @Column(nullable=false) private Integer amount;
    @Column(name="recorded_at",nullable=false) private Instant recordedAt;
    @Column(name="time_zone",nullable=false,length=64) private String timeZone;
}
