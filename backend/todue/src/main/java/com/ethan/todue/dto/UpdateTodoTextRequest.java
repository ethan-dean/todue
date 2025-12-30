package com.ethan.todue.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class UpdateTodoTextRequest {

    @NotBlank(message = "Text is required")
    private String text;
}
