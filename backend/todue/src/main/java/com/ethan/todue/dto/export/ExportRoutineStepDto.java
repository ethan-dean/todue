package com.ethan.todue.dto.export;

import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ExportRoutineStepDto {
    private Long id;
    private String text;
    private String notes;
    private Integer position;
}
