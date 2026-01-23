package com.ethan.todue.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class UpdateRoutineStepTextRequest {
    @NotBlank(message = "Text is required")
    @Size(max = 500, message = "Text must be at most 500 characters")
    private String text;
}
