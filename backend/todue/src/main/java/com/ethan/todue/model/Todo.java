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
@Table(name = "todos",
    indexes = {
        @Index(name = "idx_user_assigned_date", columnList = "user_id, assigned_date"),
        @Index(name = "idx_user_assigned_completed", columnList = "user_id, assigned_date, is_completed"),
        @Index(name = "idx_user_completed_assigned", columnList = "user_id, is_completed, assigned_date")
    },
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_recurring_instance", columnNames = {"recurring_todo_id", "instance_date"})
    }
)
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Todo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotNull
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, foreignKey = @ForeignKey(name = "fk_todo_user",
        foreignKeyDefinition = "FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE"))
    private User user;

    @NotNull
    @Column(nullable = false, length = 500)
    private String text;

    @NotNull
    @Column(nullable = false)
    private LocalDate assignedDate;

    @NotNull
    @Column(nullable = false)
    private LocalDate instanceDate;

    @Column(nullable = false)
    private Integer position = 0;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "recurring_todo_id", foreignKey = @ForeignKey(name = "fk_todo_recurring",
        foreignKeyDefinition = "FOREIGN KEY (recurring_todo_id) REFERENCES recurring_todos(id) ON DELETE SET NULL"))
    private RecurringTodo recurringTodo;

    @Column(nullable = false, columnDefinition = "BIT(1) DEFAULT 0")
    private Boolean isCompleted = false;

    @Column
    private Instant completedAt;

    @Column(nullable = false, columnDefinition = "BIT(1) DEFAULT 0")
    private Boolean isRolledOver = false;

    @CreationTimestamp
    @Column(nullable = false, updatable = false, columnDefinition = "DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6)")
    private Instant createdAt;

    @UpdateTimestamp
    @Column(nullable = false, columnDefinition = "DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)")
    private Instant updatedAt;
}
