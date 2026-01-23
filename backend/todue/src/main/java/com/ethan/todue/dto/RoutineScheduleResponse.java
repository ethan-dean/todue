package com.ethan.todue.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalTime;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class RoutineScheduleResponse {
    private Long id;
    private Integer dayOfWeek;  // 0=Sunday through 6=Saturday
    private LocalTime promptTime;  // NULL = no prompt for this day
}
