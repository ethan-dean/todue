package com.ethan.todue.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class CreateLaterListRequest {

    @NotBlank(message = "List name is required")
    @Size(max = 100, message = "List name must be at most 100 characters")
    private String listName;
}
