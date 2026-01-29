package com.ethan.todue.dto.export;

import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ExportSkipRecurringDto {
    private Integer recurringTodoRef;
    private String skipDate;
}
