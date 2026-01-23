package com.ethan.todue.service;

import com.ethan.todue.dto.*;
import com.ethan.todue.model.*;
import com.ethan.todue.repository.*;
import com.ethan.todue.websocket.WebSocketService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.*;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class RoutineService {

    @Autowired
    private RoutineRepository routineRepository;

    @Autowired
    private RoutineStepRepository routineStepRepository;

    @Autowired
    private RoutineScheduleRepository routineScheduleRepository;

    @Autowired
    private RoutineCompletionRepository routineCompletionRepository;

    @Autowired
    private RoutineStepCompletionRepository routineStepCompletionRepository;

    @Autowired
    private RoutinePromptDismissalRepository routinePromptDismissalRepository;

    @Autowired
    private UserService userService;

    @Autowired
    private WebSocketService webSocketService;

    // ==================== Routine CRUD ====================

    public List<RoutineResponse> getAllRoutines() {
        User user = userService.getCurrentUser();
        return routineRepository.findByUserIdOrderByName(user.getId())
                .stream()
                .map(this::toRoutineResponse)
                .collect(Collectors.toList());
    }

    public RoutineDetailResponse getRoutineDetail(Long routineId) {
        Routine routine = getRoutineAndVerifyOwnership(routineId);
        return toRoutineDetailResponse(routine);
    }

    @Transactional
    public RoutineResponse createRoutine(String name) {
        User user = userService.getCurrentUser();

        if (routineRepository.existsByUserIdAndName(user.getId(), name)) {
            throw new RuntimeException("A routine with this name already exists");
        }

        Routine routine = new Routine();
        routine.setUser(user);
        routine.setName(name);

        routine = routineRepository.save(routine);
        RoutineResponse response = toRoutineResponse(routine);

        webSocketService.notifyRoutineChanged(user.getId(), routine.getId(), "ROUTINE_CREATED");

        return response;
    }

    @Transactional
    public RoutineResponse updateRoutineName(Long routineId, String newName) {
        Routine routine = getRoutineAndVerifyOwnership(routineId);
        Long userId = routine.getUser().getId();

        if (routineRepository.existsByUserIdAndName(userId, newName) &&
            !routine.getName().equals(newName)) {
            throw new RuntimeException("A routine with this name already exists");
        }

        routine.setName(newName);
        routine = routineRepository.save(routine);
        RoutineResponse response = toRoutineResponse(routine);

        webSocketService.notifyRoutineChanged(userId, routineId, "ROUTINE_UPDATED");

        return response;
    }

    @Transactional
    public void deleteRoutine(Long routineId) {
        Routine routine = getRoutineAndVerifyOwnership(routineId);
        Long userId = routine.getUser().getId();

        routineRepository.delete(routine);

        webSocketService.notifyRoutineChanged(userId, routineId, "ROUTINE_DELETED");
    }

    // ==================== Step CRUD ====================

    @Transactional
    public RoutineStepResponse createStep(Long routineId, String text, String notes, Integer position) {
        Routine routine = getRoutineAndVerifyOwnership(routineId);
        Long userId = routine.getUser().getId();

        RoutineStep step = new RoutineStep();
        step.setRoutine(routine);
        step.setText(text);
        step.setNotes(notes);

        if (position != null) {
            routineStepRepository.incrementPositions(routineId, position);
            step.setPosition(position);
        } else {
            Integer maxPosition = routineStepRepository.findMaxPosition(routineId);
            step.setPosition(maxPosition + 1);
        }

        step = routineStepRepository.save(step);
        RoutineStepResponse response = toStepResponse(step);

        webSocketService.notifyRoutineChanged(userId, routineId, "ROUTINE_UPDATED");

        return response;
    }

    @Transactional
    public RoutineStepResponse updateStepText(Long routineId, Long stepId, String newText) {
        RoutineStep step = getStepAndVerifyOwnership(routineId, stepId);
        Long userId = step.getRoutine().getUser().getId();

        step.setText(newText);
        step = routineStepRepository.save(step);
        RoutineStepResponse response = toStepResponse(step);

        webSocketService.notifyRoutineChanged(userId, routineId, "ROUTINE_UPDATED");

        return response;
    }

    @Transactional
    public RoutineStepResponse updateStepNotes(Long routineId, Long stepId, String notes) {
        RoutineStep step = getStepAndVerifyOwnership(routineId, stepId);
        Long userId = step.getRoutine().getUser().getId();

        step.setNotes(notes);
        step = routineStepRepository.save(step);
        RoutineStepResponse response = toStepResponse(step);

        webSocketService.notifyRoutineChanged(userId, routineId, "ROUTINE_UPDATED");

        return response;
    }

    @Transactional
    public RoutineStepResponse updateStepPosition(Long routineId, Long stepId, Integer newPosition) {
        RoutineStep step = getStepAndVerifyOwnership(routineId, stepId);
        Long userId = step.getRoutine().getUser().getId();

        List<RoutineStep> allSteps = routineStepRepository.findByRoutineIdOrderByPosition(routineId);

        int oldIndex = -1;
        for (int i = 0; i < allSteps.size(); i++) {
            if (allSteps.get(i).getId().equals(stepId)) {
                oldIndex = i;
                break;
            }
        }

        if (oldIndex == -1) {
            throw new RuntimeException("Step not found in routine");
        }

        RoutineStep movedStep = allSteps.remove(oldIndex);
        allSteps.add(newPosition, movedStep);

        int startIdx = Math.min(oldIndex, newPosition);
        int endIdx = Math.max(oldIndex, newPosition);

        List<RoutineStep> affectedSteps = new ArrayList<>();
        for (int i = startIdx; i <= endIdx; i++) {
            allSteps.get(i).setPosition(i + 1);
            affectedSteps.add(allSteps.get(i));
        }

        routineStepRepository.saveAll(affectedSteps);
        RoutineStepResponse response = toStepResponse(step);

        webSocketService.notifyRoutineChanged(userId, routineId, "ROUTINE_UPDATED");

        return response;
    }

    @Transactional
    public void deleteStep(Long routineId, Long stepId) {
        RoutineStep step = getStepAndVerifyOwnership(routineId, stepId);
        Long userId = step.getRoutine().getUser().getId();

        routineStepRepository.delete(step);

        webSocketService.notifyRoutineChanged(userId, routineId, "ROUTINE_UPDATED");
    }

    // ==================== Schedule Management ====================

    @Transactional
    public List<RoutineScheduleResponse> setSchedules(Long routineId, List<SetRoutineSchedulesRequest.ScheduleEntry> schedules) {
        Routine routine = getRoutineAndVerifyOwnership(routineId);
        Long userId = routine.getUser().getId();

        // Delete existing schedules and flush to ensure they're removed before insert
        routineScheduleRepository.deleteByRoutineId(routineId);
        routineScheduleRepository.flush();

        if (schedules == null || schedules.isEmpty()) {
            webSocketService.notifyRoutineChanged(userId, routineId, "ROUTINE_UPDATED");
            return new ArrayList<>();
        }

        // Create new schedules
        List<RoutineSchedule> newSchedules = new ArrayList<>();
        for (SetRoutineSchedulesRequest.ScheduleEntry entry : schedules) {
            RoutineSchedule schedule = new RoutineSchedule();
            schedule.setRoutine(routine);
            schedule.setDayOfWeek(entry.getDayOfWeek());
            schedule.setPromptTime(entry.getPromptTime());
            newSchedules.add(schedule);
        }

        newSchedules = routineScheduleRepository.saveAll(newSchedules);
        List<RoutineScheduleResponse> response = newSchedules.stream()
                .map(this::toScheduleResponse)
                .collect(Collectors.toList());

        webSocketService.notifyRoutineChanged(userId, routineId, "ROUTINE_UPDATED");

        return response;
    }

    // ==================== Prompts ====================

    public List<PendingRoutinePromptResponse> getPendingPrompts() {
        User user = userService.getCurrentUser();
        LocalDate today = getCurrentDateForUser(user);
        int dayOfWeek = today.getDayOfWeek().getValue() % 7;  // Convert to 0=Sunday format

        // Get routine IDs scheduled for today with prompts
        List<Long> scheduledRoutineIds = routineScheduleRepository.findRoutineIdsWithScheduleForDay(user.getId(), dayOfWeek);

        if (scheduledRoutineIds.isEmpty()) {
            return new ArrayList<>();
        }

        // Filter out dismissed routines
        List<Long> dismissedIds = routinePromptDismissalRepository.findDismissedRoutineIdsByUserIdAndDate(user.getId(), today);

        // Filter out already completed today
        List<PendingRoutinePromptResponse> pendingPrompts = new ArrayList<>();
        for (Long routineId : scheduledRoutineIds) {
            if (dismissedIds.contains(routineId)) {
                continue;
            }

            if (routineCompletionRepository.existsCompletedByRoutineIdAndDate(routineId, today)) {
                continue;
            }

            Routine routine = routineRepository.findById(routineId).orElse(null);
            if (routine == null) {
                continue;
            }

            Integer stepCount = routineStepRepository.countByRoutineId(routineId);
            RoutineSchedule schedule = routineScheduleRepository.findByRoutineIdAndDayOfWeek(routineId, dayOfWeek).orElse(null);

            pendingPrompts.add(new PendingRoutinePromptResponse(
                    routineId,
                    routine.getName(),
                    stepCount,
                    schedule != null ? schedule.getPromptTime() : null
            ));
        }

        return pendingPrompts;
    }

    @Transactional
    public void dismissPrompt(Long routineId) {
        User user = userService.getCurrentUser();
        LocalDate today = getCurrentDateForUser(user);

        // Verify ownership
        getRoutineAndVerifyOwnership(routineId);

        // Check if already dismissed
        if (routinePromptDismissalRepository.existsByUserIdAndRoutineIdAndDismissedDate(user.getId(), routineId, today)) {
            return;  // Already dismissed
        }

        Routine routine = routineRepository.findById(routineId).orElseThrow(() -> new RuntimeException("Routine not found"));

        RoutinePromptDismissal dismissal = new RoutinePromptDismissal();
        dismissal.setUser(user);
        dismissal.setRoutine(routine);
        dismissal.setDismissedDate(today);

        routinePromptDismissalRepository.save(dismissal);
    }

    // ==================== Execution ====================

    @Transactional
    public RoutineCompletionResponse startRoutine(Long routineId) {
        Routine routine = getRoutineAndVerifyOwnership(routineId);
        User user = userService.getCurrentUser();
        LocalDate today = getCurrentDateForUser(user);

        // Check if there's already an active execution
        Optional<RoutineCompletion> existingActive = routineCompletionRepository.findActiveByRoutineId(routineId);
        if (existingActive.isPresent()) {
            return toCompletionResponse(existingActive.get());
        }

        // Create new completion
        RoutineCompletion completion = new RoutineCompletion();
        completion.setRoutine(routine);
        completion.setUser(user);
        completion.setDate(today);
        completion.setStartedAt(Instant.now());
        completion.setStatus(RoutineCompletionStatus.IN_PROGRESS);

        completion = routineCompletionRepository.save(completion);

        // Create step completions for all steps
        List<RoutineStep> steps = routineStepRepository.findByRoutineIdOrderByPosition(routineId);
        for (RoutineStep step : steps) {
            RoutineStepCompletion stepCompletion = new RoutineStepCompletion();
            stepCompletion.setCompletion(completion);
            stepCompletion.setStep(step);
            stepCompletion.setStatus(RoutineStepCompletionStatus.PENDING);
            stepCompletion.setNotes(step.getNotes());  // Copy notes from step definition
            routineStepCompletionRepository.save(stepCompletion);
        }

        webSocketService.notifyRoutineChanged(user.getId(), routineId, "EXECUTION_STARTED");

        return toCompletionResponse(completion);
    }

    @Transactional(readOnly = true)
    public RoutineCompletionResponse getActiveExecution(Long routineId) {
        getRoutineAndVerifyOwnership(routineId);

        Optional<RoutineCompletion> active = routineCompletionRepository.findActiveByRoutineId(routineId);
        return active.map(this::toCompletionResponse).orElse(null);
    }

    @Transactional
    public RoutineStepCompletionResponse completeStep(Long completionId, Long stepId, String action, String notes) {
        RoutineCompletion completion = getCompletionAndVerifyOwnership(completionId);
        User user = userService.getCurrentUser();

        if (completion.getStatus() != RoutineCompletionStatus.IN_PROGRESS) {
            throw new RuntimeException("Cannot modify a finished routine execution");
        }

        RoutineStepCompletion stepCompletion = routineStepCompletionRepository
                .findByCompletionIdAndStepId(completionId, stepId)
                .orElseThrow(() -> new RuntimeException("Step completion not found"));

        if ("complete".equalsIgnoreCase(action)) {
            stepCompletion.setStatus(RoutineStepCompletionStatus.COMPLETED);
            stepCompletion.setCompletedAt(Instant.now());
        } else if ("skip".equalsIgnoreCase(action)) {
            stepCompletion.setStatus(RoutineStepCompletionStatus.SKIPPED);
            stepCompletion.setCompletedAt(Instant.now());
        } else {
            throw new RuntimeException("Invalid action. Use 'complete' or 'skip'");
        }

        if (notes != null) {
            stepCompletion.setNotes(notes);
        }

        stepCompletion = routineStepCompletionRepository.save(stepCompletion);

        webSocketService.notifyRoutineChanged(user.getId(), completion.getRoutine().getId(), "STEP_COMPLETED");

        return toStepCompletionResponse(stepCompletion);
    }

    @Transactional
    public RoutineCompletionResponse finishExecution(Long completionId) {
        RoutineCompletion completion = getCompletionAndVerifyOwnership(completionId);
        User user = userService.getCurrentUser();

        if (completion.getStatus() != RoutineCompletionStatus.IN_PROGRESS) {
            throw new RuntimeException("Routine is already finished");
        }

        completion.setStatus(RoutineCompletionStatus.COMPLETED);
        completion.setCompletedAt(Instant.now());
        completion = routineCompletionRepository.save(completion);

        webSocketService.notifyRoutineChanged(user.getId(), completion.getRoutine().getId(), "EXECUTION_COMPLETED");

        return toCompletionResponse(completion);
    }

    @Transactional
    public RoutineCompletionResponse abandonExecution(Long completionId) {
        RoutineCompletion completion = getCompletionAndVerifyOwnership(completionId);
        User user = userService.getCurrentUser();

        if (completion.getStatus() != RoutineCompletionStatus.IN_PROGRESS) {
            throw new RuntimeException("Routine is already finished");
        }

        completion.setStatus(RoutineCompletionStatus.ABANDONED);
        completion.setCompletedAt(Instant.now());
        completion = routineCompletionRepository.save(completion);

        webSocketService.notifyRoutineChanged(user.getId(), completion.getRoutine().getId(), "EXECUTION_ABANDONED");

        return toCompletionResponse(completion);
    }

    @Transactional
    public RoutineCompletionResponse quickCompleteRoutine(Long routineId, List<Long> completedStepIds) {
        Routine routine = getRoutineAndVerifyOwnership(routineId);
        User user = userService.getCurrentUser();
        LocalDate today = getCurrentDateForUser(user);

        // Check if there's already a completed execution for today
        if (routineCompletionRepository.existsCompletedByRoutineIdAndDate(routineId, today)) {
            throw new RuntimeException("Routine already completed today");
        }

        // If there's an active execution, abandon it first
        Optional<RoutineCompletion> existingActive = routineCompletionRepository.findActiveByRoutineId(routineId);
        if (existingActive.isPresent()) {
            RoutineCompletion active = existingActive.get();
            active.setStatus(RoutineCompletionStatus.ABANDONED);
            active.setCompletedAt(Instant.now());
            routineCompletionRepository.save(active);
        }

        // Create new completion
        RoutineCompletion completion = new RoutineCompletion();
        completion.setRoutine(routine);
        completion.setUser(user);
        completion.setDate(today);
        completion.setStartedAt(Instant.now());
        completion.setCompletedAt(Instant.now());
        completion.setStatus(RoutineCompletionStatus.COMPLETED);

        completion = routineCompletionRepository.save(completion);

        // Create step completions
        List<RoutineStep> steps = routineStepRepository.findByRoutineIdOrderByPosition(routineId);
        boolean allSteps = (completedStepIds == null || completedStepIds.isEmpty());

        for (RoutineStep step : steps) {
            RoutineStepCompletion stepCompletion = new RoutineStepCompletion();
            stepCompletion.setCompletion(completion);
            stepCompletion.setStep(step);
            stepCompletion.setNotes(step.getNotes());
            stepCompletion.setCompletedAt(Instant.now());

            if (allSteps || completedStepIds.contains(step.getId())) {
                stepCompletion.setStatus(RoutineStepCompletionStatus.COMPLETED);
            } else {
                stepCompletion.setStatus(RoutineStepCompletionStatus.SKIPPED);
            }

            routineStepCompletionRepository.save(stepCompletion);
        }

        webSocketService.notifyRoutineChanged(user.getId(), routineId, "EXECUTION_COMPLETED");

        return toCompletionResponse(completion);
    }

    // ==================== Analytics ====================

    public RoutineAnalyticsResponse getAnalytics(Long routineId, LocalDate startDate, LocalDate endDate) {
        Routine routine = getRoutineAndVerifyOwnership(routineId);

        // Get all completions in date range
        List<RoutineCompletion> completions = routineCompletionRepository
                .findByRoutineIdAndDateRange(routineId, startDate, endDate);

        // Build calendar data
        Map<LocalDate, String> calendarData = new HashMap<>();
        for (RoutineCompletion completion : completions) {
            calendarData.put(completion.getDate(), completion.getStatus().name());
        }

        // Calculate stats
        long totalCompletions = routineCompletionRepository.countByRoutineIdAndStatusAndDateRange(
                routineId, RoutineCompletionStatus.COMPLETED, startDate, endDate);
        long totalAbandoned = routineCompletionRepository.countByRoutineIdAndStatusAndDateRange(
                routineId, RoutineCompletionStatus.ABANDONED, startDate, endDate);

        // Calculate completion rate
        long totalDays = java.time.temporal.ChronoUnit.DAYS.between(startDate, endDate) + 1;
        double completionRate = totalDays > 0 ? (totalCompletions * 100.0 / totalDays) : 0;

        // Calculate streaks
        int currentStreak = calculateCurrentStreak(routineId);
        int longestStreak = calculateLongestStreak(routineId);

        // Calculate per-step analytics
        List<RoutineAnalyticsResponse.StepAnalytics> stepAnalytics = calculateStepAnalytics(routineId, startDate, endDate);

        return new RoutineAnalyticsResponse(
                routineId,
                routine.getName(),
                calendarData,
                currentStreak,
                longestStreak,
                completionRate,
                totalCompletions,
                totalAbandoned,
                stepAnalytics
        );
    }

    public List<RoutineHistoryResponse> getHistory(Long routineId, LocalDate startDate, LocalDate endDate) {
        getRoutineAndVerifyOwnership(routineId);

        List<RoutineCompletion> completions = routineCompletionRepository
                .findByRoutineIdAndDateRange(routineId, startDate, endDate);

        return completions.stream()
                .map(this::toHistoryResponse)
                .collect(Collectors.toList());
    }

    // ==================== Helper Methods ====================

    private Routine getRoutineAndVerifyOwnership(Long routineId) {
        Routine routine = routineRepository.findById(routineId)
                .orElseThrow(() -> new RuntimeException("Routine not found"));

        User currentUser = userService.getCurrentUser();
        if (!routine.getUser().getId().equals(currentUser.getId())) {
            throw new RuntimeException("Unauthorized access to routine");
        }

        return routine;
    }

    private RoutineStep getStepAndVerifyOwnership(Long routineId, Long stepId) {
        Routine routine = getRoutineAndVerifyOwnership(routineId);

        RoutineStep step = routineStepRepository.findById(stepId)
                .orElseThrow(() -> new RuntimeException("Step not found"));

        if (!step.getRoutine().getId().equals(routineId)) {
            throw new RuntimeException("Step does not belong to this routine");
        }

        return step;
    }

    private RoutineCompletion getCompletionAndVerifyOwnership(Long completionId) {
        RoutineCompletion completion = routineCompletionRepository.findById(completionId)
                .orElseThrow(() -> new RuntimeException("Completion not found"));

        User currentUser = userService.getCurrentUser();
        if (!completion.getUser().getId().equals(currentUser.getId())) {
            throw new RuntimeException("Unauthorized access to completion");
        }

        return completion;
    }

    private LocalDate getCurrentDateForUser(User user) {
        ZoneId userZone = ZoneId.of(user.getTimezone() != null ? user.getTimezone() : "UTC");
        return LocalDate.now(userZone);
    }

    private int calculateCurrentStreak(Long routineId) {
        List<RoutineCompletion> completions = routineCompletionRepository
                .findCompletedByRoutineIdOrderByDateDesc(routineId);

        if (completions.isEmpty()) {
            return 0;
        }

        User user = userService.getCurrentUser();
        LocalDate today = getCurrentDateForUser(user);
        LocalDate expectedDate = today;

        int streak = 0;
        for (RoutineCompletion completion : completions) {
            if (completion.getDate().equals(expectedDate)) {
                streak++;
                expectedDate = expectedDate.minusDays(1);
            } else if (completion.getDate().equals(expectedDate.minusDays(1)) && streak == 0) {
                // Allow starting streak from yesterday if today hasn't been completed yet
                expectedDate = expectedDate.minusDays(1);
                if (completion.getDate().equals(expectedDate)) {
                    streak++;
                    expectedDate = expectedDate.minusDays(1);
                }
            } else {
                break;
            }
        }

        return streak;
    }

    private int calculateLongestStreak(Long routineId) {
        List<RoutineCompletion> completions = routineCompletionRepository
                .findCompletedByRoutineIdOrderByDateDesc(routineId);

        if (completions.isEmpty()) {
            return 0;
        }

        // Sort by date ascending for streak calculation
        completions.sort(Comparator.comparing(RoutineCompletion::getDate));

        int longestStreak = 1;
        int currentStreak = 1;
        LocalDate prevDate = completions.get(0).getDate();

        for (int i = 1; i < completions.size(); i++) {
            LocalDate currentDate = completions.get(i).getDate();
            if (currentDate.equals(prevDate.plusDays(1))) {
                currentStreak++;
                longestStreak = Math.max(longestStreak, currentStreak);
            } else if (!currentDate.equals(prevDate)) {
                currentStreak = 1;
            }
            prevDate = currentDate;
        }

        return longestStreak;
    }

    private List<RoutineAnalyticsResponse.StepAnalytics> calculateStepAnalytics(Long routineId, LocalDate startDate, LocalDate endDate) {
        List<RoutineStep> steps = routineStepRepository.findByRoutineIdOrderByPosition(routineId);
        List<RoutineCompletion> completions = routineCompletionRepository
                .findByRoutineIdAndDateRange(routineId, startDate, endDate);

        List<Long> completionIds = completions.stream()
                .map(RoutineCompletion::getId)
                .collect(Collectors.toList());

        List<RoutineAnalyticsResponse.StepAnalytics> analytics = new ArrayList<>();

        for (RoutineStep step : steps) {
            long completedCount = 0;
            long skippedCount = 0;

            for (Long completionId : completionIds) {
                Optional<RoutineStepCompletion> stepCompletion = routineStepCompletionRepository
                        .findByCompletionIdAndStepId(completionId, step.getId());

                if (stepCompletion.isPresent()) {
                    if (stepCompletion.get().getStatus() == RoutineStepCompletionStatus.COMPLETED) {
                        completedCount++;
                    } else if (stepCompletion.get().getStatus() == RoutineStepCompletionStatus.SKIPPED) {
                        skippedCount++;
                    }
                }
            }

            long total = completedCount + skippedCount;
            double completionRate = total > 0 ? (completedCount * 100.0 / total) : 0;

            analytics.add(new RoutineAnalyticsResponse.StepAnalytics(
                    step.getId(),
                    step.getText(),
                    completedCount,
                    skippedCount,
                    completionRate
            ));
        }

        return analytics;
    }

    // ==================== Response Mappers ====================

    private RoutineResponse toRoutineResponse(Routine routine) {
        Integer stepCount = routineStepRepository.countByRoutineId(routine.getId());
        return new RoutineResponse(
                routine.getId(),
                routine.getName(),
                stepCount
        );
    }

    private RoutineDetailResponse toRoutineDetailResponse(Routine routine) {
        List<RoutineStepResponse> steps = routineStepRepository.findByRoutineIdOrderByPosition(routine.getId())
                .stream()
                .map(this::toStepResponse)
                .collect(Collectors.toList());

        List<RoutineScheduleResponse> schedules = routineScheduleRepository.findByRoutineIdOrderByDayOfWeek(routine.getId())
                .stream()
                .map(this::toScheduleResponse)
                .collect(Collectors.toList());

        return new RoutineDetailResponse(
                routine.getId(),
                routine.getName(),
                steps,
                schedules
        );
    }

    private RoutineStepResponse toStepResponse(RoutineStep step) {
        return new RoutineStepResponse(
                step.getId(),
                step.getText(),
                step.getNotes(),
                step.getPosition()
        );
    }

    private RoutineScheduleResponse toScheduleResponse(RoutineSchedule schedule) {
        return new RoutineScheduleResponse(
                schedule.getId(),
                schedule.getDayOfWeek(),
                schedule.getPromptTime()
        );
    }

    private RoutineCompletionResponse toCompletionResponse(RoutineCompletion completion) {
        List<RoutineStepCompletionResponse> stepCompletions = routineStepCompletionRepository
                .findByCompletionIdOrderByStepPosition(completion.getId())
                .stream()
                .map(this::toStepCompletionResponse)
                .collect(Collectors.toList());

        int totalSteps = stepCompletions.size();
        int completedSteps = (int) stepCompletions.stream()
                .filter(sc -> "COMPLETED".equals(sc.getStatus()))
                .count();
        int skippedSteps = (int) stepCompletions.stream()
                .filter(sc -> "SKIPPED".equals(sc.getStatus()))
                .count();

        return new RoutineCompletionResponse(
                completion.getId(),
                completion.getRoutine().getId(),
                completion.getRoutine().getName(),
                completion.getDate(),
                completion.getStartedAt(),
                completion.getCompletedAt(),
                completion.getStatus().name(),
                stepCompletions,
                totalSteps,
                completedSteps,
                skippedSteps
        );
    }

    private RoutineStepCompletionResponse toStepCompletionResponse(RoutineStepCompletion stepCompletion) {
        RoutineStep step = stepCompletion.getStep();
        return new RoutineStepCompletionResponse(
                stepCompletion.getId(),
                step.getId(),
                step.getText(),
                step.getNotes(),
                step.getPosition(),
                stepCompletion.getStatus().name(),
                stepCompletion.getCompletedAt(),
                stepCompletion.getNotes()
        );
    }

    private RoutineHistoryResponse toHistoryResponse(RoutineCompletion completion) {
        List<RoutineStepCompletion> stepCompletions = routineStepCompletionRepository
                .findByCompletionIdOrderByStepPosition(completion.getId());

        int totalSteps = stepCompletions.size();
        int completedSteps = (int) stepCompletions.stream()
                .filter(sc -> sc.getStatus() == RoutineStepCompletionStatus.COMPLETED)
                .count();
        int skippedSteps = (int) stepCompletions.stream()
                .filter(sc -> sc.getStatus() == RoutineStepCompletionStatus.SKIPPED)
                .count();

        return new RoutineHistoryResponse(
                completion.getId(),
                completion.getDate(),
                completion.getStartedAt(),
                completion.getCompletedAt(),
                completion.getStatus().name(),
                totalSteps,
                completedSteps,
                skippedSteps
        );
    }
}
