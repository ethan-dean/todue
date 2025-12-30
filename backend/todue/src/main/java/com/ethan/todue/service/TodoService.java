package com.ethan.todue.service;

import com.ethan.todue.dto.TodoResponse;
import com.ethan.todue.model.RecurringTodo;
import com.ethan.todue.model.Todo;
import com.ethan.todue.model.User;
import com.ethan.todue.repository.RecurringTodoRepository;
import com.ethan.todue.repository.SkipRecurringRepository;
import com.ethan.todue.repository.TodoRepository;
import com.ethan.todue.util.RecurrenceCalculator;
import com.ethan.todue.util.RecurrenceParser;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class TodoService {

    @Autowired
    private TodoRepository todoRepository;

    @Autowired
    private RecurringTodoRepository recurringTodoRepository;

    @Autowired
    private SkipRecurringRepository skipRecurringRepository;

    @Autowired
    private UserService userService;

    @Autowired
    private SkipRecurringService skipRecurringService;

    @Autowired
    private RolloverService rolloverService;

    @Autowired
    private com.ethan.todue.websocket.WebSocketService webSocketService;

    @Transactional
    public TodoResponse createTodo(String text, LocalDate assignedDate) {
        User user = userService.getCurrentUser();

        // Check if text contains recurrence pattern
        RecurrenceParser.RecurrenceInfo recurrenceInfo = RecurrenceParser.parseText(text);

        if (recurrenceInfo != null) {
            // Create recurring todo
            RecurringTodo recurringTodo = new RecurringTodo();
            recurringTodo.setUser(user);
            recurringTodo.setText(recurrenceInfo.getStrippedText());
            recurringTodo.setRecurrenceType(recurrenceInfo.getType());
            recurringTodo.setStartDate(assignedDate);

            recurringTodo = recurringTodoRepository.save(recurringTodo);

            // Create first instance (position 0, will sort by ID)
            Todo firstInstance = new Todo();
            firstInstance.setUser(user);
            firstInstance.setText(recurrenceInfo.getStrippedText());
            firstInstance.setAssignedDate(assignedDate);
            firstInstance.setInstanceDate(assignedDate);
            firstInstance.setPosition(0);
            firstInstance.setRecurringTodo(recurringTodo);
            firstInstance.setIsCompleted(false);
            firstInstance.setIsRolledOver(false);

            firstInstance = todoRepository.save(firstInstance);
            TodoResponse response = toTodoResponse(firstInstance);

            // Send WebSocket notification - recurring pattern created affects all dates
            webSocketService.notifyRecurringChanged(user.getId());

            return response;
        } else {
            // Create regular todo
            Todo todo = new Todo();
            todo.setUser(user);
            todo.setText(text);
            todo.setAssignedDate(assignedDate);
            todo.setInstanceDate(assignedDate);
            todo.setPosition(getNextPosition(user.getId(), assignedDate));
            todo.setIsCompleted(false);
            todo.setIsRolledOver(false);

            todo = todoRepository.save(todo);
            TodoResponse response = toTodoResponse(todo);

            // Send WebSocket notification - regular todo affects only this date
            webSocketService.notifyTodosChanged(user.getId(), assignedDate);

            return response;
        }
    }

    @Transactional
    public List<TodoResponse> getTodosForDate(LocalDate date) {
        User user = userService.getCurrentUser();
        LocalDate currentDate = userService.getCurrentDateForUser();

        // Check if rollover is needed
        if (rolloverService.shouldTriggerRollover(user.getId(), date, currentDate)) {
            rolloverService.performRollover(user.getId(), currentDate);
        }

        // Get real todos
        List<Todo> realTodos = todoRepository.findByUserIdAndAssignedDate(user.getId(), date);
        List<TodoResponse> responses = realTodos.stream()
                .map(this::toTodoResponse)
                .collect(Collectors.toList());

        // Generate virtual todos for current or future dates
        if (!date.isBefore(currentDate)) {
            List<TodoResponse> virtuals = generateVirtualTodos(user.getId(), date);
            responses.addAll(virtuals);
        }

        // Sort: rolled over first, then by position, then by id
        responses.sort(Comparator
                .comparing(TodoResponse::getIsRolledOver, Comparator.reverseOrder())
                .thenComparing(TodoResponse::getPosition)
                .thenComparing(TodoResponse::getId, Comparator.nullsLast(Comparator.naturalOrder())));

        return responses;
    }

    public List<TodoResponse> getTodosForDateRange(LocalDate startDate, LocalDate endDate) {
        User user = userService.getCurrentUser();

        // Get real todos
        List<Todo> realTodos = todoRepository.findByUserIdAndAssignedDateBetween(user.getId(), startDate, endDate);
        List<TodoResponse> responses = realTodos.stream()
                .map(this::toTodoResponse)
                .collect(Collectors.toList());

        // Generate virtual todos for each date in range
        LocalDate currentDate = userService.getCurrentDateForUser();
        LocalDate date = startDate;
        while (!date.isAfter(endDate)) {
            if (!date.isBefore(currentDate)) {
                List<TodoResponse> virtuals = generateVirtualTodos(user.getId(), date);
                responses.addAll(virtuals);
            }
            date = date.plusDays(1);
        }

        // Sort by assigned date, then rolled over, then position
        responses.sort(Comparator
                .comparing(TodoResponse::getAssignedDate)
                .thenComparing(TodoResponse::getIsRolledOver, Comparator.reverseOrder())
                .thenComparing(TodoResponse::getPosition)
                .thenComparing(TodoResponse::getId, Comparator.nullsLast(Comparator.naturalOrder())));

        return responses;
    }

    public List<TodoResponse> generateVirtualTodos(Long userId, LocalDate date) {
        List<TodoResponse> virtuals = new ArrayList<>();

        // Get all active recurring todos for user
        List<RecurringTodo> recurringTodos = recurringTodoRepository.findActiveByUserIdAndDate(userId, date);

        for (RecurringTodo recurring : recurringTodos) {
            // Check if instance should exist on this date
            if (RecurrenceCalculator.shouldInstanceExist(recurring.getRecurrenceType(), recurring.getStartDate(), date)) {
                // Check if real todo already exists
                if (todoRepository.findFirstByRecurringTodoIdAndInstanceDate(recurring.getId(), date).isEmpty()) {
                    // Check if this instance is skipped
                    if (!skipRecurringRepository.existsByRecurringTodoIdAndSkipDate(recurring.getId(), date)) {
                        // Create virtual todo (position 0, will sort by recurring ID)
                        TodoResponse virtual = new TodoResponse();
                        virtual.setId(null); // Virtual has no ID
                        virtual.setText(recurring.getText());
                        virtual.setAssignedDate(date);
                        virtual.setInstanceDate(date);
                        virtual.setPosition(0);
                        virtual.setRecurringTodoId(recurring.getId());
                        virtual.setIsCompleted(false);
                        virtual.setCompletedAt(null);
                        virtual.setIsRolledOver(false);
                        virtual.setIsVirtual(true);
                        virtuals.add(virtual);
                    }
                }
            }
        }

        return virtuals;
    }

    @Transactional
    public TodoResponse materializeVirtual(Long recurringTodoId, LocalDate instanceDate) {
        User user = userService.getCurrentUser();

        RecurringTodo recurringTodo = recurringTodoRepository.findById(recurringTodoId)
                .orElseThrow(() -> new RuntimeException("Recurring todo not found"));

        if (!recurringTodo.getUser().getId().equals(user.getId())) {
            throw new RuntimeException("Unauthorized access");
        }

        Todo todo = new Todo();
        todo.setUser(user);
        todo.setText(recurringTodo.getText());
        todo.setAssignedDate(instanceDate);
        todo.setInstanceDate(instanceDate);
        todo.setPosition(0); // Position 0 for recurring todos, will sort by ID
        todo.setRecurringTodo(recurringTodo);
        todo.setIsCompleted(false);
        todo.setIsRolledOver(false);

        todo = todoRepository.save(todo);
        return toTodoResponse(todo);
    }

    @Transactional
    public TodoResponse updateTodoText(Long todoId, String newText) {
        Todo todo = getTodoAndVerifyOwnership(todoId);
        Long userId = todo.getUser().getId();

        // If this todo is linked to a recurring pattern, orphan it
        if (todo.getRecurringTodo() != null) {
            todo.setRecurringTodo(null);
        }

        todo.setText(newText);
        todo = todoRepository.save(todo);
        TodoResponse response = toTodoResponse(todo);

        // Send WebSocket notification - text update affects only assigned date
        webSocketService.notifyTodosChanged(userId, todo.getAssignedDate());

        return response;
    }

    @Transactional
    public TodoResponse updateTodoPosition(Long todoId, Integer newPosition) {
        Todo todo = getTodoAndVerifyOwnership(todoId);
        Long userId = todo.getUser().getId();

        todo.setPosition(newPosition);
        todo = todoRepository.save(todo);
        TodoResponse response = toTodoResponse(todo);

        // Send WebSocket notification - reorder affects only assigned date
        webSocketService.notifyTodosChanged(userId, todo.getAssignedDate());

        return response;
    }

    @Transactional
    public TodoResponse completeTodo(Long todoId) {
        Todo todo = getTodoAndVerifyOwnership(todoId);
        Long userId = todo.getUser().getId();

        todo.setIsCompleted(true);
        todo.setCompletedAt(Instant.now());
        todo = todoRepository.save(todo);
        TodoResponse response = toTodoResponse(todo);

        // Send WebSocket notification - completion affects only assigned date
        webSocketService.notifyTodosChanged(userId, todo.getAssignedDate());

        return response;
    }

    @Transactional
    public void deleteTodo(Long todoId, Boolean deleteAllFuture) {
        Todo todo = getTodoAndVerifyOwnership(todoId);
        Long userId = todo.getUser().getId();
        LocalDate assignedDate = todo.getAssignedDate();

        if (deleteAllFuture != null && deleteAllFuture && todo.getRecurringTodo() != null) {
            // Update recurring todo end_date
            RecurringTodo recurring = todo.getRecurringTodo();
            recurring.setEndDate(todo.getInstanceDate().minusDays(1));
            recurringTodoRepository.save(recurring);

            // Delete all future incomplete instances
            todoRepository.findFutureIncompleteTodosForRecurring(
                    recurring.getId(),
                    todo.getInstanceDate()
            ).forEach(todoRepository::delete);

            todoRepository.delete(todo);

            // Send WebSocket notification - deleting all future affects all dates
            webSocketService.notifyRecurringChanged(userId);
        } else {
            todoRepository.delete(todo);

            // Send WebSocket notification - single delete affects only assigned date
            webSocketService.notifyTodosChanged(userId, assignedDate);
        }
    }

    // Virtual todo operations

    @Transactional
    public TodoResponse completeVirtualTodo(Long recurringTodoId, LocalDate instanceDate) {
        // Materialize the virtual todo
        TodoResponse materialized = materializeVirtual(recurringTodoId, instanceDate);

        // Now complete it
        return completeTodo(materialized.getId());
    }

    @Transactional
    public void deleteVirtualTodo(Long recurringTodoId, LocalDate instanceDate, Boolean deleteAllFuture) {
        User user = userService.getCurrentUser();
        RecurringTodo recurringTodo = recurringTodoRepository.findById(recurringTodoId)
                .orElseThrow(() -> new RuntimeException("Recurring todo not found"));

        if (!recurringTodo.getUser().getId().equals(user.getId())) {
            throw new RuntimeException("Unauthorized access");
        }

        if (deleteAllFuture != null && deleteAllFuture) {
            // Delete all future instances
            recurringTodo.setEndDate(instanceDate.minusDays(1));
            recurringTodoRepository.save(recurringTodo);

            // Delete all future incomplete real instances
            todoRepository.findFutureIncompleteTodosForRecurring(
                    recurringTodo.getId(),
                    instanceDate
            ).forEach(todoRepository::delete);

            // Send WebSocket notification - deleting all future affects all dates
            webSocketService.notifyRecurringChanged(user.getId());
        } else {
            // Skip just this instance
            skipRecurringService.skipInstance(recurringTodoId, instanceDate);

            // Send WebSocket notification - skipping single instance affects only this date
            webSocketService.notifyTodosChanged(user.getId(), instanceDate);
        }
    }

    @Transactional
    public TodoResponse updateVirtualTodoText(Long recurringTodoId, LocalDate instanceDate, String newText) {
        User user = userService.getCurrentUser();

        // Skip this instance
        skipRecurringService.skipInstance(recurringTodoId, instanceDate);

        // Create orphaned todo with new text
        Todo todo = new Todo();
        todo.setUser(user);
        todo.setText(newText);
        todo.setAssignedDate(instanceDate);
        todo.setInstanceDate(instanceDate);
        todo.setPosition(getNextPosition(user.getId(), instanceDate));
        todo.setIsCompleted(false);
        todo.setIsRolledOver(false);

        todo = todoRepository.save(todo);
        TodoResponse response = toTodoResponse(todo);

        // Send WebSocket notification - orphaning affects only this date
        webSocketService.notifyTodosChanged(user.getId(), instanceDate);

        return response;
    }

    @Transactional
    public TodoResponse updateVirtualTodoPosition(Long recurringTodoId, LocalDate instanceDate, Integer newPosition) {
        // Materialize with new position
        TodoResponse materialized = materializeVirtual(recurringTodoId, instanceDate);

        // Update position
        return updateTodoPosition(materialized.getId(), newPosition);
    }

    private Todo getTodoAndVerifyOwnership(Long todoId) {
        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new RuntimeException("Todo not found"));

        User currentUser = userService.getCurrentUser();
        if (!todo.getUser().getId().equals(currentUser.getId())) {
            throw new RuntimeException("Unauthorized access to todo");
        }

        return todo;
    }

    private Integer getNextPosition(Long userId, LocalDate date) {
        List<Todo> todos = todoRepository.findByUserIdAndAssignedDate(userId, date);
        return todos.stream()
                .mapToInt(Todo::getPosition)
                .max()
                .orElse(0) + 10;
    }

    private TodoResponse toTodoResponse(Todo todo) {
        return new TodoResponse(
                todo.getId(),
                todo.getText(),
                todo.getAssignedDate(),
                todo.getInstanceDate(),
                todo.getPosition(),
                todo.getRecurringTodo() != null ? todo.getRecurringTodo().getId() : null,
                todo.getIsCompleted(),
                todo.getCompletedAt(),
                todo.getIsRolledOver(),
                false // isVirtual - will be true for generated todos
        );
    }
}
