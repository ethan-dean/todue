package com.ethan.todue.dto.importdata;

import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ImportRequest {
    private String format;  // "TEUXDEUX" or "TODUE"
    private Object data;    // Raw JSON data
}
