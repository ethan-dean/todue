package com.ethan.todue.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class UpdateRoutineStepPositionRequest {
    @NotNull(message = "Position is required")
    @Min(value = 0, message = "Position must be non-negative")
    private Integer position;
}
