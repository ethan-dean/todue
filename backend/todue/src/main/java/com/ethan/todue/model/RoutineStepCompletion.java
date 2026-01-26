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
@Table(name = "routine_step_completions",
    indexes = {
        @Index(name = "idx_routine_step_completions_completion_id", columnList = "completion_id")
    },
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_completion_step", columnNames = {"completion_id", "step_id"})
    }
)
@Data
@NoArgsConstructor
@AllArgsConstructor
public class RoutineStepCompletion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotNull
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "completion_id", nullable = false, foreignKey = @ForeignKey(name = "fk_step_completion_completion",
        foreignKeyDefinition = "FOREIGN KEY (completion_id) REFERENCES routine_completions(id) ON DELETE CASCADE"))
    private RoutineCompletion completion;

    @NotNull
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "step_id", nullable = false, foreignKey = @ForeignKey(name = "fk_step_completion_step",
        foreignKeyDefinition = "FOREIGN KEY (step_id) REFERENCES routine_steps(id) ON DELETE CASCADE"))
    private RoutineStep step;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private RoutineStepCompletionStatus status = RoutineStepCompletionStatus.PENDING;

    @Column(columnDefinition = "DATETIME(6)")
    private Instant completedAt;

    @CreationTimestamp
    @Column(nullable = false, updatable = false, columnDefinition = "DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6)")
    private Instant createdAt;

    @UpdateTimestamp
    @Column(nullable = false, columnDefinition = "DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)")
    private Instant updatedAt;
}
