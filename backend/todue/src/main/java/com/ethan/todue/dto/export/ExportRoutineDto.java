package com.ethan.todue.dto.export;

import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ExportRoutineDto {
    private Long id;
    private String name;
    private List<ExportRoutineStepDto> steps;
    private List<ExportRoutineScheduleDto> schedules;
}
