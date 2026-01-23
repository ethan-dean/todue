package com.ethan.todue.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.time.LocalTime;

@Entity
@Table(name = "routine_schedules",
    indexes = {
        @Index(name = "idx_routine_schedules_routine_id", columnList = "routine_id")
    },
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_routine_day", columnNames = {"routine_id", "day_of_week"})
    }
)
@Data
@NoArgsConstructor
@AllArgsConstructor
public class RoutineSchedule {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotNull
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "routine_id", nullable = false, foreignKey = @ForeignKey(name = "fk_routine_schedule_routine",
        foreignKeyDefinition = "FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE"))
    private Routine routine;

    @NotNull
    @Column(name = "day_of_week", nullable = false)
    private Integer dayOfWeek;  // 0=Sunday through 6=Saturday

    @Column(name = "prompt_time")
    private LocalTime promptTime;  // NULL = no prompt for this day

    @CreationTimestamp
    @Column(nullable = false, updatable = false, columnDefinition = "DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6)")
    private Instant createdAt;

    @UpdateTimestamp
    @Column(nullable = false, columnDefinition = "DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)")
    private Instant updatedAt;
}
