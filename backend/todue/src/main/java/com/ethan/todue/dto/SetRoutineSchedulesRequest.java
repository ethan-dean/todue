package com.ethan.todue.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalTime;
import java.util.List;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class SetRoutineSchedulesRequest {
    @Valid
    private List<ScheduleEntry> schedules;

    @Data
    @AllArgsConstructor
    @NoArgsConstructor
    public static class ScheduleEntry {
        @NotNull(message = "Day of week is required")
        @Min(value = 0, message = "Day of week must be between 0 (Sunday) and 6 (Saturday)")
        @Max(value = 6, message = "Day of week must be between 0 (Sunday) and 6 (Saturday)")
        private Integer dayOfWeek;

        private LocalTime promptTime;  // NULL means no prompt for this day
    }
}
