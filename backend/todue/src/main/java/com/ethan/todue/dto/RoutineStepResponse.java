package com.ethan.todue.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class RoutineStepResponse {
    private Long id;
    private String text;
    private String notes;
    private Integer position;
}
