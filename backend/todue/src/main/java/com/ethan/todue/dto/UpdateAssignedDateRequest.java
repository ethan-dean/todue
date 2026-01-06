package com.ethan.todue.dto;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class UpdateAssignedDateRequest {

    @NotNull(message = "Target date is required")
    private LocalDate toDate;
}
