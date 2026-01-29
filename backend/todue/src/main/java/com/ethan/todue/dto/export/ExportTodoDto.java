package com.ethan.todue.dto.export;

import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ExportTodoDto {
    private Long id;
    private String text;
    private String assignedDate;
    private String instanceDate;
    private Integer position;
    private Integer recurringTodoRef;
    private Boolean isCompleted;
    private String completedAt;
    private Boolean isRolledOver;
}
