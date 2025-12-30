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
@Table(name = "skip_recurring",
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_recurring_skip_date", columnNames = {"recurring_todo_id", "skip_date"})
    },
    indexes = {
        @Index(name = "idx_recurring_todo_id", columnList = "recurring_todo_id")
    }
)
@Data
@NoArgsConstructor
@AllArgsConstructor
public class SkipRecurring {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotNull
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "recurring_todo_id", nullable = false, foreignKey = @ForeignKey(name = "fk_skip_recurring_todo",
        foreignKeyDefinition = "FOREIGN KEY (recurring_todo_id) REFERENCES recurring_todos(id) ON DELETE CASCADE"))
    private RecurringTodo recurringTodo;

    @NotNull
    @Column(nullable = false)
    private LocalDate skipDate;

    @CreationTimestamp
    @Column(nullable = false, updatable = false, columnDefinition = "DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6)")
    private Instant createdAt;
}
