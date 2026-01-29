package com.ethan.todue.dto.importdata;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class TeuxDeuxWorkspace {
    private String timezone;

    @JsonProperty("calendar_todos")
    private List<TeuxDeuxCalendarTodo> calendarTodos;

    @JsonProperty("recurring_todos")
    private List<TeuxDeuxRecurringTodo> recurringTodos;

    @JsonProperty("list_sets")
    private List<TeuxDeuxListSet> listSets;
}
