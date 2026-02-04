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
@Table(name = "later_list_todos",
    indexes = {
        @Index(name = "idx_later_list_todos_list_id", columnList = "list_id")
    }
)
@Data
@NoArgsConstructor
@AllArgsConstructor
public class LaterListTodo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotNull
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "list_id", nullable = false, foreignKey = @ForeignKey(name = "fk_later_list_todo_list",
        foreignKeyDefinition = "FOREIGN KEY (list_id) REFERENCES later_lists(id) ON DELETE CASCADE"))
    private LaterList list;

    @NotNull
    @Column(nullable = false, length = 500)
    private String text;

    @Column(nullable = false, columnDefinition = "BIT(1) DEFAULT 0")
    private Boolean isCompleted = false;

    @Column
    private Instant completedAt;

    @Column(nullable = false)
    private Integer position = 0;

    @Version
    @Column(nullable = false)
    private Long version = 0L;

    @CreationTimestamp
    @Column(nullable = false, updatable = false, columnDefinition = "DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6)")
    private Instant createdAt;

    @UpdateTimestamp
    @Column(nullable = false, columnDefinition = "DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)")
    private Instant updatedAt;
}
