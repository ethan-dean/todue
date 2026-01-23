package com.ethan.todue.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.time.LocalDate;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class RoutineHistoryResponse {
    private Long id;
    private LocalDate date;
    private Instant startedAt;
    private Instant completedAt;
    private String status;  // IN_PROGRESS, COMPLETED, ABANDONED
    private Integer totalSteps;
    private Integer completedSteps;
    private Integer skippedSteps;
}
