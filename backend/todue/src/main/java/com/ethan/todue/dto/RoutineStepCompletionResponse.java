package com.ethan.todue.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class RoutineStepCompletionResponse {
    private Long id;
    private Long stepId;
    private String stepText;
    private String stepNotes;  // Notes from step definition
    private Integer stepPosition;
    private String status;  // PENDING, COMPLETED, SKIPPED
    private Instant completedAt;
}
