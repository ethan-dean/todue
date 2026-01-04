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

            // Check if we're creating this on the current date
            LocalDate currentDate = userService.getCurrentDateForUser();
            if (assignedDate.equals(currentDate)) {
                // Auto-materialize for current day
                Todo firstInstance = new Todo();
                firstInstance.setUser(user);
                firstInstance.setText(recurrenceInfo.getStrippedText());
                firstInstance.setAssignedDate(assignedDate);
                firstInstance.setInstanceDate(assignedDate);
                firstInstance.setPosition(getNextPosition(user.getId(), assignedDate));
                firstInstance.setRecurringTodo(recurringTodo);
                firstInstance.setIsCompleted(false);
                firstInstance.setIsRolledOver(false);

                firstInstance = todoRepository.save(firstInstance);
                TodoResponse response = toTodoResponse(firstInstance);

                // Send both notifications - recurring pattern created AND current day changed
                webSocketService.notifyRecurringChanged(user.getId());
                webSocketService.notifyTodosChanged(user.getId(), assignedDate);

                return response;
            } else {
                // Creating for future date - return virtual todo response
                TodoResponse virtualResponse = new TodoResponse(
                        null, // id
                        recurrenceInfo.getStrippedText(), // text
                        assignedDate, // assignedDate
                        assignedDate, // instanceDate
                        0, // position - virtuals at 0
                        recurringTodo.getId(), // recurringTodoId
                        false, // isCompleted
                        null, // completedAt
                        false, // isRolledOver
                        true // isVirtual
                );

                // Send notification - recurring pattern affects all future dates
                webSocketService.notifyRecurringChanged(user.getId());

                return virtualResponse;
            }
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

        // Get real todos (already sorted by repository: isCompleted ASC, position ASC, id ASC)
        List<Todo> realTodos = todoRepository.findByUserIdAndAssignedDate(user.getId(), date);
        List<TodoResponse> responses = realTodos.stream()
                .map(this::toTodoResponse)
                .collect(Collectors.toList());

        // Generate virtual todos for current or future dates
        if (!date.isBefore(currentDate)) {
            List<TodoResponse> virtuals = generateVirtualTodos(user.getId(), date);
            responses.addAll(virtuals);
        }

        // Sort by position only (position determines order including completion status)
        responses.sort(Comparator.comparing(TodoResponse::getPosition));

        return responses;
    }

    public List<TodoResponse> getTodosForDateRange(LocalDate startDate, LocalDate endDate) {
        User user = userService.getCurrentUser();

        // Get real todos (already sorted by repository)
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

        // Sort by assigned date, then position (position determines order including completion status)
        responses.sort(Comparator
                .comparing(TodoResponse::getAssignedDate)
                .thenComparing(TodoResponse::getPosition));

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
            // Add to skip_recurring to prevent future rollover of this instance
            skipRecurringService.skipInstance(
                    todo.getRecurringTodo().getId(),
                    todo.getInstanceDate()
            );

            // Remove the link
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
        LocalDate assignedDate = todo.getAssignedDate();

        // Get all todos for this date, sorted by position
        List<Todo> allTodos = todoRepository.findByUserIdAndAssignedDate(userId, assignedDate);
        allTodos.sort(Comparator.comparing(Todo::getPosition).thenComparing(Todo::getId));

        // Find current index
        int oldIndex = -1;
        for (int i = 0; i < allTodos.size(); i++) {
            if (allTodos.get(i).getId().equals(todoId)) {
                oldIndex = i;
                break;
            }
        }

        if (oldIndex == -1) {
            throw new RuntimeException("Todo not found in list");
        }

        // Remove from old position, insert at new position
        Todo movedTodo = allTodos.remove(oldIndex);
        allTodos.add(newPosition, movedTodo);

        // Only renumber the affected range (between old and new positions)
        int startIdx = Math.min(oldIndex, newPosition);
        int endIdx = Math.max(oldIndex, newPosition);

        List<Todo> affectedTodos = new ArrayList<>();
        for (int i = startIdx; i <= endIdx; i++) {
            allTodos.get(i).setPosition(i + 1);
            affectedTodos.add(allTodos.get(i));
        }

        // Save only the modified todos
        todoRepository.saveAll(affectedTodos);

        // Send WebSocket notification - reorder affects only assigned date
        webSocketService.notifyTodosChanged(userId, assignedDate);

        return toTodoResponse(todo);
    }

    @Transactional
    public TodoResponse completeTodo(Long todoId) {
        Todo todo = getTodoAndVerifyOwnership(todoId);
        Long userId = todo.getUser().getId();
        LocalDate assignedDate = todo.getAssignedDate();

        // Get all todos for this date, sorted by position
        List<Todo> allTodos = todoRepository.findByUserIdAndAssignedDate(userId, assignedDate);
        allTodos.sort(Comparator.comparing(Todo::getPosition).thenComparing(Todo::getId));

        // Find current index
        int oldIndex = -1;
        for (int i = 0; i < allTodos.size(); i++) {
            if (allTodos.get(i).getId().equals(todoId)) {
                oldIndex = i;
                break;
            }
        }

        if (oldIndex == -1) {
            throw new RuntimeException("Todo not found in list");
        }

        // Find first completed todo position (or end if none)
        int firstCompletedIndex = allTodos.size(); // Default to end
        for (int i = 0; i < allTodos.size(); i++) {
            if (allTodos.get(i).getIsCompleted()) {
                firstCompletedIndex = i;
                break;
            }
        }

        // Mark as completed
        todo.setIsCompleted(true);
        todo.setCompletedAt(Instant.now());

        // Move to top of completed section (just before first completed, or end)
        Todo movedTodo = allTodos.remove(oldIndex);
        // Adjust index if we're moving forward
        int newIndex = firstCompletedIndex > oldIndex ? firstCompletedIndex - 1 : firstCompletedIndex;
        allTodos.add(newIndex, movedTodo);

        // Renumber affected range
        int startIdx = Math.min(oldIndex, newIndex);
        int endIdx = Math.max(oldIndex, newIndex);

        List<Todo> affectedTodos = new ArrayList<>();
        for (int i = startIdx; i <= endIdx; i++) {
            allTodos.get(i).setPosition(i + 1);
            affectedTodos.add(allTodos.get(i));
        }

        todoRepository.saveAll(affectedTodos);
        TodoResponse response = toTodoResponse(todo);

        // Send WebSocket notification - completion affects only assigned date
        webSocketService.notifyTodosChanged(userId, assignedDate);

        return response;
    }

    @Transactional
    public TodoResponse uncompleteTodo(Long todoId) {
        Todo todo = getTodoAndVerifyOwnership(todoId);
        Long userId = todo.getUser().getId();
        LocalDate assignedDate = todo.getAssignedDate();

        // Get all todos for this date, sorted by position
        List<Todo> allTodos = todoRepository.findByUserIdAndAssignedDate(userId, assignedDate);
        allTodos.sort(Comparator.comparing(Todo::getPosition).thenComparing(Todo::getId));

        // Find current index
        int oldIndex = -1;
        for (int i = 0; i < allTodos.size(); i++) {
            if (allTodos.get(i).getId().equals(todoId)) {
                oldIndex = i;
                break;
            }
        }

        if (oldIndex == -1) {
            throw new RuntimeException("Todo not found in list");
        }

        // Find first completed todo position (end of incomplete section)
        int firstCompletedIndex = allTodos.size(); // Default to end if none completed
        for (int i = 0; i < allTodos.size(); i++) {
            if (allTodos.get(i).getIsCompleted() && !allTodos.get(i).getId().equals(todoId)) {
                firstCompletedIndex = i;
                break;
            }
        }

        // Mark as incomplete
        todo.setIsCompleted(false);
        todo.setCompletedAt(null);

        // Move to end of incomplete section (right before first completed)
        Todo movedTodo = allTodos.remove(oldIndex);
        // Adjust index if we removed before the target
        int newIndex = firstCompletedIndex > oldIndex ? firstCompletedIndex - 1 : firstCompletedIndex;
        allTodos.add(newIndex, movedTodo);

        // Renumber affected range
        int startIdx = Math.min(oldIndex, newIndex);
        int endIdx = Math.max(oldIndex, newIndex);

        List<Todo> affectedTodos = new ArrayList<>();
        for (int i = startIdx; i <= endIdx; i++) {
            allTodos.get(i).setPosition(i + 1);
            affectedTodos.add(allTodos.get(i));
        }

        todoRepository.saveAll(affectedTodos);
        TodoResponse response = toTodoResponse(todo);

        // Send WebSocket notification - uncompletion affects only assigned date
        webSocketService.notifyTodosChanged(userId, assignedDate);

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
        User user = userService.getCurrentUser();

        RecurringTodo recurring = recurringTodoRepository.findById(recurringTodoId)
                .orElseThrow(() -> new RuntimeException("Recurring todo not found"));

        if (!recurring.getUser().getId().equals(user.getId())) {
            throw new RuntimeException("Unauthorized");
        }

        LocalDate currentDate = userService.getCurrentDateForUser();

        // If this is a future date, check if we need to materialize virtuals
        if (instanceDate.isAfter(currentDate)) {
            // Get all normal todos for this date
            List<Todo> normalTodos = todoRepository.findByUserIdAndAssignedDate(user.getId(), instanceDate)
                    .stream()
                    .filter(t -> t.getRecurringTodo() == null) // Only normal todos
                    .collect(Collectors.toList());

            // If user is placing normal todo at position that would be in virtual group
            // (virtuals are at top with position 0), materialize all virtuals
            if (newPosition <= normalTodos.size()) {
                // Materialize all virtuals for this date
                List<RecurringTodo> allRecurring = recurringTodoRepository.findActiveByUserIdAndDate(
                        user.getId(), instanceDate);

                int pos = 1;
                for (RecurringTodo rec : allRecurring) {
                    // Check if not already materialized
                    if (todoRepository.findFirstByRecurringTodoIdAndInstanceDate(
                            rec.getId(), instanceDate).isEmpty()) {

                        Todo materialized = new Todo();
                        materialized.setUser(user);
                        materialized.setText(rec.getText());
                        materialized.setAssignedDate(instanceDate);
                        materialized.setInstanceDate(instanceDate);
                        materialized.setPosition(pos++);
                        materialized.setRecurringTodo(rec);
                        materialized.setIsCompleted(false);
                        materialized.setIsRolledOver(false);

                        todoRepository.save(materialized);
                    }
                }

                // Renumber normal todos to continue from materialized virtuals
                normalTodos.sort(Comparator.comparing(Todo::getPosition));
                for (Todo normalTodo : normalTodos) {
                    normalTodo.setPosition(pos++);
                }
                todoRepository.saveAll(normalTodos);
            }
        }

        // Now materialize this specific virtual and apply position
        TodoResponse materialized = materializeVirtual(recurringTodoId, instanceDate);
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
                .orElse(0) + 1; // Sequential: max + 1
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
