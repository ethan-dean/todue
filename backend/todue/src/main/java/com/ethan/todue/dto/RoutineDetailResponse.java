package com.ethan.todue.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class RoutineDetailResponse {
    private Long id;
    private String name;
    private List<RoutineStepResponse> steps;
    private List<RoutineScheduleResponse> schedules;
}
