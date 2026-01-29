package com.ethan.todue.service;

import com.ethan.todue.dto.export.*;
import com.ethan.todue.dto.importdata.*;
import com.ethan.todue.model.*;
import com.ethan.todue.repository.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeParseException;
import java.util.*;

@Service
public class ImportService {

    private static final Logger logger = LoggerFactory.getLogger(ImportService.class);

    @Autowired
    private UserService userService;

    @Autowired
    private TodoRepository todoRepository;

    @Autowired
    private RecurringTodoRepository recurringTodoRepository;

    @Autowired
    private SkipRecurringRepository skipRecurringRepository;

    @Autowired
    private LaterListRepository laterListRepository;

    @Autowired
    private LaterListTodoRepository laterListTodoRepository;

    @Autowired
    private RoutineRepository routineRepository;

    @Autowired
    private RoutineStepRepository routineStepRepository;

    @Autowired
    private RoutineScheduleRepository routineScheduleRepository;

    @Autowired
    private ObjectMapper objectMapper;

    @Transactional
    public ImportResponse importData(ImportRequest request) {
        String format = request.getFormat();

        if ("TEUXDEUX".equalsIgnoreCase(format)) {
            return importTeuxDeux(request.getData());
        } else if ("TODUE".equalsIgnoreCase(format)) {
            return importTodue(request.getData());
        } else {
            return new ImportResponse(false, "Unknown import format: " + format, null);
        }
    }

    private ImportResponse importTeuxDeux(Object data) {
        User user = userService.getCurrentUser();
        ImportStats stats = new ImportStats();

        try {
            TeuxDeuxImportDto importDto = objectMapper.convertValue(data, TeuxDeuxImportDto.class);

            if (importDto.getWorkspaces() == null || importDto.getWorkspaces().isEmpty()) {
                return new ImportResponse(false, "No workspaces found in TeuxDeux export", null);
            }

            // Track TeuxDeux recurring todo ID to our RecurringTodo entity
            Map<String, RecurringTodo> teuxDeuxRecurringMap = new HashMap<>();

            for (TeuxDeuxWorkspace workspace : importDto.getWorkspaces()) {
                // Import recurring todos first
                if (workspace.getRecurringTodos() != null) {
                    for (TeuxDeuxRecurringTodo teuxRecurring : workspace.getRecurringTodos()) {
                        try {
                            RecurrenceType recurrenceType = parseRrule(teuxRecurring.getRecurrenceRule());
                            if (recurrenceType == null) {
                                stats.addWarning("Skipped recurring todo with unsupported recurrence rule: " + teuxRecurring.getRecurrenceRule());
                                continue;
                            }

                            RecurringTodo recurring = new RecurringTodo();
                            recurring.setUser(user);
                            recurring.setText(teuxRecurring.getText());
                            recurring.setRecurrenceType(recurrenceType);
                            recurring.setStartDate(parseDate(teuxRecurring.getStartDate()));
                            if (teuxRecurring.getEndDate() != null && !teuxRecurring.getEndDate().isEmpty()) {
                                recurring.setEndDate(parseDate(teuxRecurring.getEndDate()));
                            }
                            recurring = recurringTodoRepository.save(recurring);
                            teuxDeuxRecurringMap.put(teuxRecurring.getId(), recurring);
                            stats.setRecurringTodosImported(stats.getRecurringTodosImported() + 1);
                        } catch (Exception e) {
                            stats.addWarning("Failed to import recurring todo: " + teuxRecurring.getText() + " - " + e.getMessage());
                        }
                    }
                }

                // Import calendar todos
                if (workspace.getCalendarTodos() != null) {
                    for (TeuxDeuxCalendarTodo calTodo : workspace.getCalendarTodos()) {
                        try {
                            String text = combineTextAndDetails(calTodo.getText(), calTodo.getDetails());
                            LocalDate date = parseDate(calTodo.getCurrentDate());

                            Todo todo = new Todo();
                            todo.setUser(user);
                            todo.setText(text);
                            todo.setAssignedDate(date);
                            todo.setInstanceDate(date);
                            todo.setPosition(calTodo.getPosition() != null ? calTodo.getPosition() * 10 : 0);
                            todo.setIsCompleted(Boolean.TRUE.equals(calTodo.getDone()));
                            if (Boolean.TRUE.equals(calTodo.getDone())) {
                                todo.setCompletedAt(Instant.now());
                            }
                            todo.setIsRolledOver(false);

                            // Link to recurring if exists
                            if (calTodo.getRecurringTodoId() != null && teuxDeuxRecurringMap.containsKey(calTodo.getRecurringTodoId())) {
                                todo.setRecurringTodo(teuxDeuxRecurringMap.get(calTodo.getRecurringTodoId()));
                            }

                            todoRepository.save(todo);
                            stats.setTodosImported(stats.getTodosImported() + 1);
                        } catch (Exception e) {
                            stats.addWarning("Failed to import todo: " + calTodo.getText() + " - " + e.getMessage());
                        }
                    }
                }

                // Import list sets as later lists
                if (workspace.getListSets() != null) {
                    for (TeuxDeuxListSet listSet : workspace.getListSets()) {
                        if (listSet.getLists() != null) {
                            for (TeuxDeuxList list : listSet.getLists()) {
                                try {
                                    // Flatten: "ListSetName: ListName"
                                    String listName = listSet.getName() + ": " + list.getName();

                                    // Ensure unique list name
                                    String finalListName = listName;
                                    int counter = 1;
                                    while (laterListRepository.existsByUserIdAndListName(user.getId(), finalListName)) {
                                        finalListName = listName + " (" + counter + ")";
                                        counter++;
                                    }

                                    LaterList laterList = new LaterList();
                                    laterList.setUser(user);
                                    laterList.setListName(finalListName);
                                    laterList = laterListRepository.save(laterList);
                                    stats.setLaterListsImported(stats.getLaterListsImported() + 1);

                                    // Import todos in this list
                                    if (list.getTodos() != null) {
                                        for (TeuxDeuxListTodo listTodo : list.getTodos()) {
                                            try {
                                                String text = combineTextAndDetails(listTodo.getText(), listTodo.getDetails());

                                                LaterListTodo laterTodo = new LaterListTodo();
                                                laterTodo.setList(laterList);
                                                laterTodo.setText(text);
                                                laterTodo.setPosition(listTodo.getPosition() != null ? listTodo.getPosition() * 10 : 0);
                                                laterTodo.setIsCompleted(Boolean.TRUE.equals(listTodo.getDone()));
                                                if (Boolean.TRUE.equals(listTodo.getDone())) {
                                                    laterTodo.setCompletedAt(Instant.now());
                                                }

                                                laterListTodoRepository.save(laterTodo);
                                                stats.setLaterListTodosImported(stats.getLaterListTodosImported() + 1);
                                            } catch (Exception e) {
                                                stats.addWarning("Failed to import list todo: " + listTodo.getText() + " - " + e.getMessage());
                                            }
                                        }
                                    }
                                } catch (Exception e) {
                                    stats.addWarning("Failed to import list: " + list.getName() + " - " + e.getMessage());
                                }
                            }
                        }
                    }
                }
            }

            return new ImportResponse(true, "Import completed successfully", stats);

        } catch (Exception e) {
            logger.error("Failed to import TeuxDeux data", e);
            return new ImportResponse(false, "Failed to parse TeuxDeux data: " + e.getMessage(), stats);
        }
    }

    private ImportResponse importTodue(Object data) {
        User user = userService.getCurrentUser();
        ImportStats stats = new ImportStats();
        int skippedDuplicates = 0;

        try {
            TodueExportDto importDto = objectMapper.convertValue(data, TodueExportDto.class);

            // Map from exportRef to RecurringTodo entity (existing or new)
            Map<Integer, RecurringTodo> refToRecurring = new HashMap<>();

            // Import recurring todos first
            if (importDto.getRecurringTodos() != null) {
                for (ExportRecurringTodoDto exportRecurring : importDto.getRecurringTodos()) {
                    try {
                        // Check if already exists by ID
                        if (exportRecurring.getId() != null) {
                            Optional<RecurringTodo> existing = recurringTodoRepository.findById(exportRecurring.getId());
                            if (existing.isPresent() && existing.get().getUser().getId().equals(user.getId())) {
                                // Already exists, use existing one for references
                                refToRecurring.put(exportRecurring.getExportRef(), existing.get());
                                skippedDuplicates++;
                                continue;
                            }
                        }

                        RecurringTodo recurring = new RecurringTodo();
                        recurring.setUser(user);
                        recurring.setText(exportRecurring.getText());
                        recurring.setRecurrenceType(RecurrenceType.valueOf(exportRecurring.getRecurrenceType()));
                        recurring.setStartDate(LocalDate.parse(exportRecurring.getStartDate()));
                        if (exportRecurring.getEndDate() != null) {
                            recurring.setEndDate(LocalDate.parse(exportRecurring.getEndDate()));
                        }
                        recurring = recurringTodoRepository.save(recurring);
                        refToRecurring.put(exportRecurring.getExportRef(), recurring);
                        stats.setRecurringTodosImported(stats.getRecurringTodosImported() + 1);
                    } catch (Exception e) {
                        stats.addWarning("Failed to import recurring todo: " + exportRecurring.getText() + " - " + e.getMessage());
                    }
                }
            }

            // Import skip recurring entries
            if (importDto.getSkipRecurring() != null) {
                for (ExportSkipRecurringDto exportSkip : importDto.getSkipRecurring()) {
                    try {
                        RecurringTodo recurring = refToRecurring.get(exportSkip.getRecurringTodoRef());
                        if (recurring != null) {
                            // Check if skip already exists
                            LocalDate skipDate = LocalDate.parse(exportSkip.getSkipDate());
                            if (skipRecurringRepository.existsByRecurringTodoIdAndSkipDate(recurring.getId(), skipDate)) {
                                skippedDuplicates++;
                                continue;
                            }
                            SkipRecurring skip = new SkipRecurring();
                            skip.setRecurringTodo(recurring);
                            skip.setSkipDate(skipDate);
                            skipRecurringRepository.save(skip);
                            stats.setSkipRecurringImported(stats.getSkipRecurringImported() + 1);
                        }
                    } catch (Exception e) {
                        stats.addWarning("Failed to import skip recurring: " + e.getMessage());
                    }
                }
            }

            // Import todos
            if (importDto.getTodos() != null) {
                for (ExportTodoDto exportTodo : importDto.getTodos()) {
                    try {
                        // Check if already exists by ID
                        if (exportTodo.getId() != null) {
                            Optional<Todo> existing = todoRepository.findById(exportTodo.getId());
                            if (existing.isPresent() && existing.get().getUser().getId().equals(user.getId())) {
                                skippedDuplicates++;
                                continue;
                            }
                        }

                        Todo todo = new Todo();
                        todo.setUser(user);
                        todo.setText(exportTodo.getText());
                        todo.setAssignedDate(LocalDate.parse(exportTodo.getAssignedDate()));
                        todo.setInstanceDate(LocalDate.parse(exportTodo.getInstanceDate()));
                        todo.setPosition(exportTodo.getPosition());
                        todo.setIsCompleted(Boolean.TRUE.equals(exportTodo.getIsCompleted()));
                        if (exportTodo.getCompletedAt() != null) {
                            todo.setCompletedAt(Instant.parse(exportTodo.getCompletedAt()));
                        }
                        todo.setIsRolledOver(Boolean.TRUE.equals(exportTodo.getIsRolledOver()));

                        if (exportTodo.getRecurringTodoRef() != null && refToRecurring.containsKey(exportTodo.getRecurringTodoRef())) {
                            todo.setRecurringTodo(refToRecurring.get(exportTodo.getRecurringTodoRef()));
                        }

                        todoRepository.save(todo);
                        stats.setTodosImported(stats.getTodosImported() + 1);
                    } catch (Exception e) {
                        stats.addWarning("Failed to import todo: " + exportTodo.getText() + " - " + e.getMessage());
                    }
                }
            }

            // Import later lists
            if (importDto.getLaterLists() != null) {
                for (ExportLaterListDto exportList : importDto.getLaterLists()) {
                    try {
                        // Check if already exists by ID
                        if (exportList.getId() != null) {
                            Optional<LaterList> existing = laterListRepository.findById(exportList.getId());
                            if (existing.isPresent() && existing.get().getUser().getId().equals(user.getId())) {
                                skippedDuplicates++;
                                // Still need to check todos in this list
                                LaterList existingList = existing.get();
                                if (exportList.getTodos() != null) {
                                    for (ExportLaterListTodoDto exportTodo : exportList.getTodos()) {
                                        if (exportTodo.getId() != null) {
                                            Optional<LaterListTodo> existingTodo = laterListTodoRepository.findById(exportTodo.getId());
                                            if (existingTodo.isPresent()) {
                                                skippedDuplicates++;
                                                continue;
                                            }
                                        }
                                        try {
                                            LaterListTodo laterTodo = new LaterListTodo();
                                            laterTodo.setList(existingList);
                                            laterTodo.setText(exportTodo.getText());
                                            laterTodo.setPosition(exportTodo.getPosition());
                                            laterTodo.setIsCompleted(Boolean.TRUE.equals(exportTodo.getIsCompleted()));
                                            if (exportTodo.getCompletedAt() != null) {
                                                laterTodo.setCompletedAt(Instant.parse(exportTodo.getCompletedAt()));
                                            }
                                            laterListTodoRepository.save(laterTodo);
                                            stats.setLaterListTodosImported(stats.getLaterListTodosImported() + 1);
                                        } catch (Exception e) {
                                            stats.addWarning("Failed to import list todo: " + exportTodo.getText() + " - " + e.getMessage());
                                        }
                                    }
                                }
                                continue;
                            }
                        }

                        // Ensure unique list name
                        String listName = exportList.getListName();
                        String finalListName = listName;
                        int counter = 1;
                        while (laterListRepository.existsByUserIdAndListName(user.getId(), finalListName)) {
                            finalListName = listName + " (" + counter + ")";
                            counter++;
                        }

                        LaterList laterList = new LaterList();
                        laterList.setUser(user);
                        laterList.setListName(finalListName);
                        laterList = laterListRepository.save(laterList);
                        stats.setLaterListsImported(stats.getLaterListsImported() + 1);

                        if (exportList.getTodos() != null) {
                            for (ExportLaterListTodoDto exportTodo : exportList.getTodos()) {
                                try {
                                    LaterListTodo laterTodo = new LaterListTodo();
                                    laterTodo.setList(laterList);
                                    laterTodo.setText(exportTodo.getText());
                                    laterTodo.setPosition(exportTodo.getPosition());
                                    laterTodo.setIsCompleted(Boolean.TRUE.equals(exportTodo.getIsCompleted()));
                                    if (exportTodo.getCompletedAt() != null) {
                                        laterTodo.setCompletedAt(Instant.parse(exportTodo.getCompletedAt()));
                                    }
                                    laterListTodoRepository.save(laterTodo);
                                    stats.setLaterListTodosImported(stats.getLaterListTodosImported() + 1);
                                } catch (Exception e) {
                                    stats.addWarning("Failed to import list todo: " + exportTodo.getText() + " - " + e.getMessage());
                                }
                            }
                        }
                    } catch (Exception e) {
                        stats.addWarning("Failed to import later list: " + exportList.getListName() + " - " + e.getMessage());
                    }
                }
            }

            // Import routines
            if (importDto.getRoutines() != null) {
                for (ExportRoutineDto exportRoutine : importDto.getRoutines()) {
                    try {
                        // Check if already exists by ID
                        if (exportRoutine.getId() != null) {
                            Optional<Routine> existing = routineRepository.findById(exportRoutine.getId());
                            if (existing.isPresent() && existing.get().getUser().getId().equals(user.getId())) {
                                skippedDuplicates++;
                                continue;
                            }
                        }

                        // Ensure unique routine name
                        String routineName = exportRoutine.getName();
                        String finalRoutineName = routineName;
                        int counter = 1;
                        while (routineRepository.existsByUserIdAndName(user.getId(), finalRoutineName)) {
                            finalRoutineName = routineName + " (" + counter + ")";
                            counter++;
                        }

                        Routine routine = new Routine();
                        routine.setUser(user);
                        routine.setName(finalRoutineName);
                        routine = routineRepository.save(routine);
                        stats.setRoutinesImported(stats.getRoutinesImported() + 1);

                        // Import steps
                        if (exportRoutine.getSteps() != null) {
                            for (ExportRoutineStepDto exportStep : exportRoutine.getSteps()) {
                                try {
                                    RoutineStep step = new RoutineStep();
                                    step.setRoutine(routine);
                                    step.setText(exportStep.getText());
                                    step.setNotes(exportStep.getNotes());
                                    step.setPosition(exportStep.getPosition());
                                    routineStepRepository.save(step);
                                    stats.setRoutineStepsImported(stats.getRoutineStepsImported() + 1);
                                } catch (Exception e) {
                                    stats.addWarning("Failed to import routine step: " + exportStep.getText() + " - " + e.getMessage());
                                }
                            }
                        }

                        // Import schedules
                        if (exportRoutine.getSchedules() != null) {
                            for (ExportRoutineScheduleDto exportSchedule : exportRoutine.getSchedules()) {
                                try {
                                    RoutineSchedule schedule = new RoutineSchedule();
                                    schedule.setRoutine(routine);
                                    schedule.setDayOfWeek(exportSchedule.getDayOfWeek());
                                    if (exportSchedule.getPromptTime() != null) {
                                        schedule.setPromptTime(LocalTime.parse(exportSchedule.getPromptTime()));
                                    }
                                    routineScheduleRepository.save(schedule);
                                } catch (Exception e) {
                                    stats.addWarning("Failed to import routine schedule: " + e.getMessage());
                                }
                            }
                        }
                    } catch (Exception e) {
                        stats.addWarning("Failed to import routine: " + exportRoutine.getName() + " - " + e.getMessage());
                    }
                }
            }

            String message = "Import completed successfully";
            if (skippedDuplicates > 0) {
                message += " (" + skippedDuplicates + " existing items skipped)";
            }
            return new ImportResponse(true, message, stats);

        } catch (Exception e) {
            logger.error("Failed to import Todue data", e);
            return new ImportResponse(false, "Failed to parse Todue data: " + e.getMessage(), stats);
        }
    }

    /**
     * Parse iCal RRULE to RecurrenceType enum
     */
    private RecurrenceType parseRrule(String rrule) {
        if (rrule == null || rrule.isEmpty()) {
            return null;
        }

        // Parse the RRULE format, e.g., "FREQ=DAILY", "FREQ=WEEKLY;INTERVAL=2"
        String uppercaseRule = rrule.toUpperCase();

        if (uppercaseRule.contains("FREQ=DAILY")) {
            return RecurrenceType.DAILY;
        } else if (uppercaseRule.contains("FREQ=WEEKLY")) {
            // Check for biweekly
            if (uppercaseRule.contains("INTERVAL=2")) {
                return RecurrenceType.BIWEEKLY;
            }
            return RecurrenceType.WEEKLY;
        } else if (uppercaseRule.contains("FREQ=MONTHLY")) {
            return RecurrenceType.MONTHLY;
        } else if (uppercaseRule.contains("FREQ=YEARLY")) {
            return RecurrenceType.YEARLY;
        }

        return null;
    }

    /**
     * Combine text and details, appending details in brackets if present
     */
    private String combineTextAndDetails(String text, String details) {
        if (text == null) {
            text = "";
        }
        if (details == null || details.trim().isEmpty()) {
            return text;
        }
        return text + " [" + details.trim() + "]";
    }

    /**
     * Parse date string in various formats
     */
    private LocalDate parseDate(String dateStr) {
        if (dateStr == null || dateStr.isEmpty()) {
            return LocalDate.now();
        }

        try {
            // Try ISO format first (YYYY-MM-DD)
            return LocalDate.parse(dateStr);
        } catch (DateTimeParseException e) {
            // Try other formats if needed
            try {
                // Handle full ISO datetime
                if (dateStr.contains("T")) {
                    return LocalDate.parse(dateStr.substring(0, 10));
                }
            } catch (Exception ex) {
                // Fall back to today
            }
        }
        return LocalDate.now();
    }
}
