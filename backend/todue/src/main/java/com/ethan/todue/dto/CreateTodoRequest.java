package com.ethan.todue.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;

@Data
public class CreateTodoRequest {

    @NotBlank(message = "Text is required")
    private String text;

    @NotNull(message = "Assigned date is required")
    private LocalDate assignedDate;
}
