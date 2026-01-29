package com.ethan.todue.dto.importdata;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class TeuxDeuxList {
    private String name;
    private Integer position;
    private List<TeuxDeuxListTodo> todos;
}
