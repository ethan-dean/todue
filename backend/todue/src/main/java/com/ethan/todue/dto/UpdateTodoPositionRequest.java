package com.ethan.todue.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class UpdateTodoPositionRequest {

    @NotNull(message = "Position is required")
    private Integer position;
}
