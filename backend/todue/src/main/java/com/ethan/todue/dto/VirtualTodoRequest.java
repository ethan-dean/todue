package com.ethan.todue.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;

@Data
public class VirtualTodoRequest {

    @NotNull(message = "Recurring todo ID is required")
    private Long recurringTodoId;

    @NotNull(message = "Instance date is required")
    private LocalDate instanceDate;
}
