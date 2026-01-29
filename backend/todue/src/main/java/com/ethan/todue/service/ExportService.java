package com.ethan.todue.service;

import com.ethan.todue.dto.export.*;
import com.ethan.todue.model.*;
import com.ethan.todue.repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class ExportService {

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

    @Transactional(readOnly = true)
    public TodueExportDto exportUserData() {
        User user = userService.getCurrentUser();
        Long userId = user.getId();

        // Build mapping from recurring todo ID to export ref (1-based index)
        List<RecurringTodo> recurringTodos = recurringTodoRepository.findByUserId(userId);
        Map<Long, Integer> recurringIdToRef = new HashMap<>();
        for (int i = 0; i < recurringTodos.size(); i++) {
            recurringIdToRef.put(recurringTodos.get(i).getId(), i + 1);
        }

        // Export recurring todos
        List<ExportRecurringTodoDto> exportRecurringTodos = recurringTodos.stream()
                .map(rt -> new ExportRecurringTodoDto(
                        rt.getId(),
                        recurringIdToRef.get(rt.getId()),
                        rt.getText(),
                        rt.getRecurrenceType().name(),
                        rt.getStartDate().toString(),
                        rt.getEndDate() != null ? rt.getEndDate().toString() : null
                ))
                .collect(Collectors.toList());

        // Export skip recurring entries
        List<ExportSkipRecurringDto> exportSkipRecurring = new ArrayList<>();
        for (RecurringTodo rt : recurringTodos) {
            List<SkipRecurring> skips = skipRecurringRepository.findByRecurringTodoId(rt.getId());
            for (SkipRecurring skip : skips) {
                exportSkipRecurring.add(new ExportSkipRecurringDto(
                        recurringIdToRef.get(rt.getId()),
                        skip.getSkipDate().toString()
                ));
            }
        }

        // Export all materialized todos
        List<Todo> allTodos = todoRepository.findAll().stream()
                .filter(t -> t.getUser().getId().equals(userId))
                .collect(Collectors.toList());

        List<ExportTodoDto> exportTodos = allTodos.stream()
                .map(todo -> new ExportTodoDto(
                        todo.getId(),
                        todo.getText(),
                        todo.getAssignedDate().toString(),
                        todo.getInstanceDate().toString(),
                        todo.getPosition(),
                        todo.getRecurringTodo() != null ? recurringIdToRef.get(todo.getRecurringTodo().getId()) : null,
                        todo.getIsCompleted(),
                        todo.getCompletedAt() != null ? todo.getCompletedAt().toString() : null,
                        todo.getIsRolledOver()
                ))
                .collect(Collectors.toList());

        // Export later lists with their todos
        List<LaterList> laterLists = laterListRepository.findByUserIdOrderByListName(userId);
        List<ExportLaterListDto> exportLaterLists = laterLists.stream()
                .map(list -> {
                    List<LaterListTodo> listTodos = laterListTodoRepository.findByListIdOrderByPosition(list.getId());
                    List<ExportLaterListTodoDto> exportListTodos = listTodos.stream()
                            .map(todo -> new ExportLaterListTodoDto(
                                    todo.getId(),
                                    todo.getText(),
                                    todo.getIsCompleted(),
                                    todo.getCompletedAt() != null ? todo.getCompletedAt().toString() : null,
                                    todo.getPosition()
                            ))
                            .collect(Collectors.toList());
                    return new ExportLaterListDto(list.getId(), list.getListName(), exportListTodos);
                })
                .collect(Collectors.toList());

        // Export routines with steps and schedules
        List<Routine> routines = routineRepository.findByUserIdOrderByName(userId);
        List<ExportRoutineDto> exportRoutines = routines.stream()
                .map(routine -> {
                    List<RoutineStep> steps = routineStepRepository.findByRoutineIdOrderByPosition(routine.getId());
                    List<ExportRoutineStepDto> exportSteps = steps.stream()
                            .map(step -> new ExportRoutineStepDto(
                                    step.getId(),
                                    step.getText(),
                                    step.getNotes(),
                                    step.getPosition()
                            ))
                            .collect(Collectors.toList());

                    List<RoutineSchedule> schedules = routineScheduleRepository.findByRoutineIdOrderByDayOfWeek(routine.getId());
                    List<ExportRoutineScheduleDto> exportSchedules = schedules.stream()
                            .map(schedule -> new ExportRoutineScheduleDto(
                                    schedule.getDayOfWeek(),
                                    schedule.getPromptTime() != null ? schedule.getPromptTime().toString() : null
                            ))
                            .collect(Collectors.toList());

                    return new ExportRoutineDto(routine.getId(), routine.getName(), exportSteps, exportSchedules);
                })
                .collect(Collectors.toList());

        return new TodueExportDto(
                "1.0",
                Instant.now().toString(),
                user.getTimezone(),
                exportTodos,
                exportRecurringTodos,
                exportSkipRecurring,
                exportLaterLists,
                exportRoutines
        );
    }
}
