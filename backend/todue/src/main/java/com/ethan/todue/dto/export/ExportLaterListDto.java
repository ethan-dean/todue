package com.ethan.todue.dto.export;

import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ExportLaterListDto {
    private Long id;
    private String listName;
    private List<ExportLaterListTodoDto> todos;
}
