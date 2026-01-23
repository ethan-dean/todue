package com.ethan.todue.dto;

import java.util.List;

public class QuickCompleteRoutineRequest {
    private List<Long> completedStepIds;  // If null or empty, all steps are marked complete

    public QuickCompleteRoutineRequest() {}

    public QuickCompleteRoutineRequest(List<Long> completedStepIds) {
        this.completedStepIds = completedStepIds;
    }

    public List<Long> getCompletedStepIds() {
        return completedStepIds;
    }

    public void setCompletedStepIds(List<Long> completedStepIds) {
        this.completedStepIds = completedStepIds;
    }
}
