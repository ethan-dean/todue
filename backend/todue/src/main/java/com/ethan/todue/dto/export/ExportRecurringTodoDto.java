package com.ethan.todue.dto.export;

import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ExportRecurringTodoDto {
    private Long id;
    private Integer exportRef;
    private String text;
    private String recurrenceType;
    private String startDate;
    private String endDate;
}
