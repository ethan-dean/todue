package com.ethan.todue.dto.importdata;

import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

import java.util.ArrayList;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ImportStats {
    private int todosImported = 0;
    private int recurringTodosImported = 0;
    private int laterListsImported = 0;
    private int laterListTodosImported = 0;
    private int routinesImported = 0;
    private int routineStepsImported = 0;
    private int skipRecurringImported = 0;
    private List<String> warnings = new ArrayList<>();

    public void addWarning(String warning) {
        warnings.add(warning);
    }
}
