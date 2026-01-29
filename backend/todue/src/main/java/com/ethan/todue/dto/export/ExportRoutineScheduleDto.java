package com.ethan.todue.dto.export;

import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ExportRoutineScheduleDto {
    private Integer dayOfWeek;
    private String promptTime;
}
