package com.ethan.todue.dto.export;

import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TodueExportDto {
    private String version;
    private String exportedAt;
    private String userTimezone;
    private List<ExportTodoDto> todos;
    private List<ExportRecurringTodoDto> recurringTodos;
    private List<ExportSkipRecurringDto> skipRecurring;
    private List<ExportLaterListDto> laterLists;
    private List<ExportRoutineDto> routines;
}
