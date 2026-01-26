package com.ethan.todue.controller;

import com.ethan.todue.dto.*;
import com.ethan.todue.service.RoutineService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/routines")
public class RoutineController {

    @Autowired
    private RoutineService routineService;

    // ==================== Routine CRUD ====================

    @GetMapping
    public ResponseEntity<List<RoutineResponse>> getAllRoutines() {
        List<RoutineResponse> routines = routineService.getAllRoutines();
        return ResponseEntity.ok(routines);
    }

    @GetMapping("/{id}")
    public ResponseEntity<RoutineDetailResponse> getRoutineDetail(@PathVariable Long id) {
        RoutineDetailResponse routine = routineService.getRoutineDetail(id);
        return ResponseEntity.ok(routine);
    }

    @PostMapping
    public ResponseEntity<RoutineResponse> createRoutine(@Valid @RequestBody CreateRoutineRequest request) {
        RoutineResponse response = routineService.createRoutine(request.getName());
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{id}/name")
    public ResponseEntity<RoutineResponse> updateRoutineName(
            @PathVariable Long id,
            @Valid @RequestBody UpdateRoutineNameRequest request
    ) {
        RoutineResponse response = routineService.updateRoutineName(id, request.getName());
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, String>> deleteRoutine(@PathVariable Long id) {
        routineService.deleteRoutine(id);
        return ResponseEntity.ok(Map.of("message", "Routine deleted successfully"));
    }

    // ==================== Step CRUD ====================

    @PostMapping("/{routineId}/steps")
    public ResponseEntity<RoutineStepResponse> createStep(
            @PathVariable Long routineId,
            @Valid @RequestBody CreateRoutineStepRequest request
    ) {
        RoutineStepResponse response = routineService.createStep(
                routineId,
                request.getText(),
                request.getNotes(),
                request.getPosition()
        );
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{routineId}/steps/{stepId}/text")
    public ResponseEntity<RoutineStepResponse> updateStepText(
            @PathVariable Long routineId,
            @PathVariable Long stepId,
            @Valid @RequestBody UpdateRoutineStepTextRequest request
    ) {
        RoutineStepResponse response = routineService.updateStepText(routineId, stepId, request.getText());
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{routineId}/steps/{stepId}/notes")
    public ResponseEntity<RoutineStepResponse> updateStepNotes(
            @PathVariable Long routineId,
            @PathVariable Long stepId,
            @Valid @RequestBody UpdateRoutineStepNotesRequest request
    ) {
        RoutineStepResponse response = routineService.updateStepNotes(routineId, stepId, request.getNotes());
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{routineId}/steps/{stepId}/position")
    public ResponseEntity<RoutineStepResponse> updateStepPosition(
            @PathVariable Long routineId,
            @PathVariable Long stepId,
            @Valid @RequestBody UpdateRoutineStepPositionRequest request
    ) {
        RoutineStepResponse response = routineService.updateStepPosition(routineId, stepId, request.getPosition());
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/{routineId}/steps/{stepId}")
    public ResponseEntity<Map<String, String>> deleteStep(
            @PathVariable Long routineId,
            @PathVariable Long stepId
    ) {
        routineService.deleteStep(routineId, stepId);
        return ResponseEntity.ok(Map.of("message", "Step deleted successfully"));
    }

    // ==================== Schedules ====================

    @PutMapping("/{routineId}/schedules")
    public ResponseEntity<List<RoutineScheduleResponse>> setSchedules(
            @PathVariable Long routineId,
            @Valid @RequestBody SetRoutineSchedulesRequest request
    ) {
        List<RoutineScheduleResponse> response = routineService.setSchedules(routineId, request.getSchedules());
        return ResponseEntity.ok(response);
    }

    // ==================== Prompts ====================

    @GetMapping("/prompts/pending")
    public ResponseEntity<List<PendingRoutinePromptResponse>> getPendingPrompts() {
        List<PendingRoutinePromptResponse> prompts = routineService.getPendingPrompts();
        return ResponseEntity.ok(prompts);
    }

    @PostMapping("/prompts/{routineId}/dismiss")
    public ResponseEntity<Map<String, String>> dismissPrompt(@PathVariable Long routineId) {
        routineService.dismissPrompt(routineId);
        return ResponseEntity.ok(Map.of("message", "Prompt dismissed"));
    }

    // ==================== Execution ====================

    @PostMapping("/{routineId}/quick-complete")
    public ResponseEntity<RoutineCompletionResponse> quickCompleteRoutine(
            @PathVariable Long routineId,
            @RequestBody(required = false) QuickCompleteRoutineRequest request
    ) {
        List<Long> completedStepIds = (request != null) ? request.getCompletedStepIds() : null;
        RoutineCompletionResponse response = routineService.quickCompleteRoutine(routineId, completedStepIds);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/{routineId}/start")
    public ResponseEntity<RoutineCompletionResponse> startRoutine(@PathVariable Long routineId) {
        RoutineCompletionResponse response = routineService.startRoutine(routineId);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/{routineId}/active")
    public ResponseEntity<RoutineCompletionResponse> getActiveExecution(@PathVariable Long routineId) {
        RoutineCompletionResponse response = routineService.getActiveExecution(routineId);
        if (response == null) {
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.ok(response);
    }

    @PostMapping("/executions/{completionId}/steps/{stepId}")
    public ResponseEntity<RoutineStepCompletionResponse> completeStep(
            @PathVariable Long completionId,
            @PathVariable Long stepId,
            @Valid @RequestBody CompleteRoutineStepRequest request
    ) {
        RoutineStepCompletionResponse response = routineService.completeStep(
                completionId,
                stepId,
                request.getAction()
        );
        return ResponseEntity.ok(response);
    }

    @PostMapping("/executions/{completionId}/finish")
    public ResponseEntity<RoutineCompletionResponse> finishExecution(@PathVariable Long completionId) {
        RoutineCompletionResponse response = routineService.finishExecution(completionId);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/executions/{completionId}/abandon")
    public ResponseEntity<RoutineCompletionResponse> abandonExecution(@PathVariable Long completionId) {
        RoutineCompletionResponse response = routineService.abandonExecution(completionId);
        return ResponseEntity.ok(response);
    }

    // ==================== Analytics ====================

    @GetMapping("/{routineId}/analytics")
    public ResponseEntity<RoutineAnalyticsResponse> getAnalytics(
            @PathVariable Long routineId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate
    ) {
        RoutineAnalyticsResponse response = routineService.getAnalytics(routineId, startDate, endDate);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/{routineId}/history")
    public ResponseEntity<List<RoutineHistoryResponse>> getHistory(
            @PathVariable Long routineId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate
    ) {
        List<RoutineHistoryResponse> response = routineService.getHistory(routineId, startDate, endDate);
        return ResponseEntity.ok(response);
    }
}
