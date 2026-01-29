package com.ethan.todue.dto.export;

import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ExportLaterListTodoDto {
    private Long id;
    private String text;
    private Boolean isCompleted;
    private String completedAt;
    private Integer position;
}
