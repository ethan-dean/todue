package com.ethan.todue.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class LaterListTodoResponse {
    private Long id;
    private String text;
    private Boolean isCompleted;
    private Instant completedAt;
    private Integer position;
}
