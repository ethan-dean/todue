package com.ethan.todue.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "routine_prompt_dismissals",
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_user_routine_date", columnNames = {"user_id", "routine_id", "dismissed_date"})
    }
)
@Data
@NoArgsConstructor
@AllArgsConstructor
public class RoutinePromptDismissal {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotNull
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, foreignKey = @ForeignKey(name = "fk_prompt_dismissal_user",
        foreignKeyDefinition = "FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE"))
    private User user;

    @NotNull
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "routine_id", nullable = false, foreignKey = @ForeignKey(name = "fk_prompt_dismissal_routine",
        foreignKeyDefinition = "FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE"))
    private Routine routine;

    @NotNull
    @Column(name = "dismissed_date", nullable = false)
    private LocalDate dismissedDate;

    @CreationTimestamp
    @Column(nullable = false, updatable = false, columnDefinition = "DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6)")
    private Instant createdAt;
}
