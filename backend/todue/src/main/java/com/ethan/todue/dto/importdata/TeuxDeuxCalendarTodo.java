package com.ethan.todue.dto.importdata;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class TeuxDeuxCalendarTodo {
    private String id;
    private String text;
    private String details;

    @JsonProperty("current_date")
    private String currentDate;

    private Boolean done;
    private Integer position;

    @JsonProperty("recurring_todo_id")
    private String recurringTodoId;
}
