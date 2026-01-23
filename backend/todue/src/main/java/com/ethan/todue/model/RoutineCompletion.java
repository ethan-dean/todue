package com.ethan.todue.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "routine_completions",
    indexes = {
        @Index(name = "idx_routine_completions_routine_date", columnList = "routine_id, date"),
        @Index(name = "idx_routine_completions_user_date", columnList = "user_id, date")
    }
)
@Data
@NoArgsConstructor
@AllArgsConstructor
public class RoutineCompletion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotNull
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "routine_id", nullable = false, foreignKey = @ForeignKey(name = "fk_routine_completion_routine",
        foreignKeyDefinition = "FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE"))
    private Routine routine;

    @NotNull
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, foreignKey = @ForeignKey(name = "fk_routine_completion_user",
        foreignKeyDefinition = "FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE"))
    private User user;

    @NotNull
    @Column(nullable = false)
    private LocalDate date;

    @NotNull
    @Column(nullable = false, columnDefinition = "DATETIME(6)")
    private Instant startedAt;

    @Column(columnDefinition = "DATETIME(6)")
    private Instant completedAt;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private RoutineCompletionStatus status = RoutineCompletionStatus.IN_PROGRESS;

    @CreationTimestamp
    @Column(nullable = false, updatable = false, columnDefinition = "DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6)")
    private Instant createdAt;

    @UpdateTimestamp
    @Column(nullable = false, columnDefinition = "DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)")
    private Instant updatedAt;
}
