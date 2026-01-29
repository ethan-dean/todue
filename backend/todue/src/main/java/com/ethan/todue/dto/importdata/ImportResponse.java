package com.ethan.todue.dto.importdata;

import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ImportResponse {
    private boolean success;
    private String message;
    private ImportStats stats;
}
