package com.ethan.todue.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;

@Entity
@Table(name = "routine_steps",
    indexes = {
        @Index(name = "idx_routine_steps_routine_id", columnList = "routine_id")
    }
)
@Data
@NoArgsConstructor
@AllArgsConstructor
public class RoutineStep {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotNull
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "routine_id", nullable = false, foreignKey = @ForeignKey(name = "fk_routine_step_routine",
        foreignKeyDefinition = "FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE"))
    private Routine routine;

    @NotNull
    @Column(nullable = false, length = 500)
    private String text;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @NotNull
    @Column(nullable = false)
    private Integer position;

    @CreationTimestamp
    @Column(nullable = false, updatable = false, columnDefinition = "DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6)")
    private Instant createdAt;

    @UpdateTimestamp
    @Column(nullable = false, columnDefinition = "DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)")
    private Instant updatedAt;
}
