package com.ethan.todue.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.time.LocalDate;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class TodoResponse {
    private Long id;
    private String text;
    private LocalDate assignedDate;
    private LocalDate instanceDate;
    private Integer position;
    private Long recurringTodoId;
    private Boolean isCompleted;
    private Instant completedAt;
    private Boolean isRolledOver;
    private Boolean isVirtual = false;
}
