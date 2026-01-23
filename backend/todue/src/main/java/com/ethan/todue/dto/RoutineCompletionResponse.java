package com.ethan.todue.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class RoutineCompletionResponse {
    private Long id;
    private Long routineId;
    private String routineName;
    private LocalDate date;
    private Instant startedAt;
    private Instant completedAt;
    private String status;  // IN_PROGRESS, COMPLETED, ABANDONED
    private List<RoutineStepCompletionResponse> stepCompletions;
    private Integer totalSteps;
    private Integer completedSteps;
    private Integer skippedSteps;
}
