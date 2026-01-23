package com.ethan.todue.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalTime;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class PendingRoutinePromptResponse {
    private Long routineId;
    private String routineName;
    private Integer stepCount;
    private LocalTime scheduledTime;  // The scheduled prompt time for today
}
