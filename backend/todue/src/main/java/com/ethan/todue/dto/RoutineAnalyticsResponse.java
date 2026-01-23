package com.ethan.todue.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class RoutineAnalyticsResponse {
    private Long routineId;
    private String routineName;

    // Calendar data - maps date to status (COMPLETED, ABANDONED, null for no execution)
    private Map<LocalDate, String> calendarData;

    // Stats
    private Integer currentStreak;
    private Integer longestStreak;
    private Double completionRate;  // Percentage (0-100) in the date range
    private Long totalCompletions;
    private Long totalAbandoned;

    // Per-step stats
    private List<StepAnalytics> stepAnalytics;

    @Data
    @AllArgsConstructor
    @NoArgsConstructor
    public static class StepAnalytics {
        private Long stepId;
        private String stepText;
        private Long completedCount;
        private Long skippedCount;
        private Double completionRate;  // completed / (completed + skipped) * 100
    }
}
