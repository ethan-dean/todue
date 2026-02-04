package com.ethan.todue.service;

import com.ethan.todue.model.RecurringTodo;
import com.ethan.todue.model.Todo;
import com.ethan.todue.model.User;
import com.ethan.todue.repository.RecurringTodoRepository;
import com.ethan.todue.repository.SkipRecurringRepository;
import com.ethan.todue.repository.TodoRepository;
import com.ethan.todue.repository.UserRepository;
import com.ethan.todue.util.RecurrenceCalculator;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

@Service
public class RolloverService {

    @Autowired
    private TodoRepository todoRepository;

    @Autowired
    private RecurringTodoRepository recurringTodoRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private SkipRecurringRepository skipRecurringRepository;

    // In-memory session state for last rollover date per user
    private final ConcurrentHashMap<Long, LocalDate> lastRolloverDateMap = new ConcurrentHashMap<>();

    @Transactional
    public void performRollover(Long userId, LocalDate currentDate) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        int position = 1; // Start at position 1 for sequential positioning

        // Step 1: Query recurring_todos and filter to only those that actually occur today
        List<RecurringTodo> allActiveRecurring = recurringTodoRepository.findActiveByUserIdAndDate(userId, currentDate);
        List<RecurringTodo> todaysRecurring = allActiveRecurring.stream()
                .filter(rec -> RecurrenceCalculator.shouldInstanceExist(rec.getRecurrenceType(), rec.getStartDate(), currentDate))
                .filter(rec -> !skipRecurringRepository.existsByRecurringTodoIdAndSkipDate(rec.getId(), currentDate))
                .collect(java.util.stream.Collectors.toList());
        java.util.Set<Long> todaysRecurringIds = todaysRecurring.stream()
                .map(RecurringTodo::getId)
                .collect(java.util.stream.Collectors.toSet());

        // Step 2: Generate rolled-over todos (check for duplicates)
        List<Todo> incompleteTodos = todoRepository.findIncompleteBeforeDate(userId, currentDate);
        List<Todo> todosToDelete = new ArrayList<>();

        // Collect source dates before mutation (the loop below changes assignedDate)
        Set<LocalDate> sourceDates = incompleteTodos.stream()
                .map(Todo::getAssignedDate)
                .collect(Collectors.toSet());

        for (Todo incompleteTodo : incompleteTodos) {
            // Delete if this recurring_todo_id will be materialized today
            if (incompleteTodo.getRecurringTodo() != null
                && todaysRecurringIds.contains(incompleteTodo.getRecurringTodo().getId())) {
                todosToDelete.add(incompleteTodo); // Mark for deletion - today's virtual will replace it
                continue;
            }

            // Roll it over
            incompleteTodo.setAssignedDate(currentDate);
            incompleteTodo.setIsRolledOver(true);
            incompleteTodo.setPosition(position++);
        }

        // Delete skipped recurring instances from past dates
        if (!todosToDelete.isEmpty()) {
            todoRepository.deleteAll(todosToDelete);
            // Remove deleted todos from the list to avoid merge conflicts
            incompleteTodos.removeAll(todosToDelete);
        }

        todoRepository.saveAll(incompleteTodos);

        // Renumber remaining todos on source dates to close position gaps
        sourceDates.forEach(date -> renumberPositions(date, userId));

        // Step 3: Materialize virtual todos for today
        for (RecurringTodo recurring : todaysRecurring) {
            // Check if real todo already exists (was manually created/materialized before)
            java.util.Optional<Todo> existingTodo = todoRepository.findFirstByRecurringTodoIdAndInstanceDate(
                recurring.getId(), currentDate);

            if (existingTodo.isEmpty()) {
                // Materialize it
                Todo materializedTodo = new Todo();
                materializedTodo.setUser(user);
                materializedTodo.setText(recurring.getText());
                materializedTodo.setAssignedDate(currentDate);
                materializedTodo.setInstanceDate(currentDate);
                materializedTodo.setPosition(position++);
                materializedTodo.setRecurringTodo(recurring);
                materializedTodo.setIsCompleted(false);
                materializedTodo.setIsRolledOver(false);

                todoRepository.save(materializedTodo);
            } else {
                // Already materialized - update position to maintain sequential order
                Todo existing = existingTodo.get();
                existing.setPosition(position++);
                todoRepository.save(existing);
            }
        }

        // Step 4: Renumber existing normal todos for current date
        List<Todo> normalTodos = todoRepository.findByUserIdAndAssignedDate(userId, currentDate);
        for (Todo todo : normalTodos) {
            // Only renumber if not already handled above
            if (!todo.getIsRolledOver() && todo.getRecurringTodo() == null) {
                todo.setPosition(position++);
            }
        }
        todoRepository.saveAll(normalTodos);

        // Update last rollover date
        user.setLastRolloverDate(Instant.now());
        userRepository.save(user);

        // Update session state
        lastRolloverDateMap.put(userId, currentDate);
    }


    private void renumberPositions(LocalDate date, Long userId) {
        List<Todo> todos = todoRepository.findByUserIdAndAssignedDate(userId, date);
        todos.sort(Comparator.comparing(Todo::getPosition).thenComparing(Todo::getId));
        int pos = 1;
        for (Todo t : todos) {
            t.setPosition(pos++);
        }
        todoRepository.saveAll(todos);
    }

    public boolean shouldTriggerRollover(Long userId, LocalDate requestedDate, LocalDate currentDate) {
        // Only rollover if requesting current date
        if (!requestedDate.equals(currentDate)) {
            return false;
        }

        // Check in-memory cache first (faster)
        LocalDate lastRollover = lastRolloverDateMap.get(userId);
        if (lastRollover != null && lastRollover.equals(currentDate)) {
            return false; // Already done today (in this server session)
        }

        // Check database (handles server restarts)
        User user = userRepository.findById(userId).orElse(null);
        if (user != null && user.getLastRolloverDate() != null) {
            // Convert Instant to LocalDate in user's timezone
            LocalDate lastRolloverFromDb = user.getLastRolloverDate()
                .atZone(java.time.ZoneId.of(user.getTimezone()))
                .toLocalDate();

            // Update in-memory cache
            if (lastRolloverFromDb.equals(currentDate)) {
                lastRolloverDateMap.put(userId, currentDate);
                return false; // Already done today (from previous server session)
            }
        }

        return true; // Needs rollover
    }
}
