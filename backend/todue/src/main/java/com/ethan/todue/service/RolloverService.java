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
import java.util.concurrent.ConcurrentHashMap;

@Service
public class RolloverService {

    @Autowired
    private TodoRepository todoRepository;

    @Autowired
    private RecurringTodoRepository recurringTodoRepository;

    @Autowired
    private SkipRecurringRepository skipRecurringRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private UserService userService;

    // In-memory session state for last rollover date per user
    private final ConcurrentHashMap<Long, LocalDate> lastRolloverDateMap = new ConcurrentHashMap<>();

    @Transactional
    public void performRollover(Long userId, LocalDate currentDate) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // Step 1: Materialize past virtuals (max 1)
        materializePastVirtuals(user, currentDate);

        // Step 2: Roll forward existing incomplete todos
        rollForwardIncompleteTodos(user, currentDate);

        // Update last rollover date
        user.setLastRolloverDate(Instant.now());
        userRepository.save(user);

        // Update session state
        lastRolloverDateMap.put(userId, currentDate);
    }

    private void materializePastVirtuals(User user, LocalDate currentDate) {
        LocalDate lastRolloverDate = user.getLastRolloverDate() != null
                ? LocalDate.ofInstant(user.getLastRolloverDate(), java.time.ZoneId.of(user.getTimezone()))
                : currentDate.minusDays(7); // Default to 7 days ago if no last rollover

        List<VirtualInstanceToMaterialize> instancesToMaterialize = new ArrayList<>();

        // Get all active recurring todos
        List<RecurringTodo> recurringTodos = recurringTodoRepository.findActiveByUserIdAndDate(user.getId(), currentDate);

        for (RecurringTodo recurring : recurringTodos) {
            LocalDate date = lastRolloverDate.isAfter(recurring.getStartDate()) ? lastRolloverDate : recurring.getStartDate();

            // Check each date between last rollover and yesterday
            while (date.isBefore(currentDate)) {
                if (RecurrenceCalculator.shouldInstanceExist(recurring.getRecurrenceType(), recurring.getStartDate(), date)) {
                    // Check if real todo already exists
                    if (todoRepository.findByRecurringTodoIdAndInstanceDate(recurring.getId(), date).isEmpty()) {
                        // Check if not skipped
                        if (!skipRecurringRepository.existsByRecurringTodoIdAndSkipDate(recurring.getId(), date)) {
                            instancesToMaterialize.add(new VirtualInstanceToMaterialize(recurring, date));
                        }
                    }
                }
                date = date.plusDays(1);
            }
        }

        // Sort by instance date (oldest first) and take max 1
        instancesToMaterialize.sort(Comparator.comparing(v -> v.instanceDate));
        int count = 0;
        int basePosition = -1000;

        for (VirtualInstanceToMaterialize instance : instancesToMaterialize) {
            if (count >= 1) break;

            Todo todo = new Todo();
            todo.setUser(user);
            todo.setText(instance.recurringTodo.getText());
            todo.setAssignedDate(currentDate);
            todo.setInstanceDate(instance.instanceDate);
            todo.setPosition(basePosition + count);
            todo.setRecurringTodo(instance.recurringTodo);
            todo.setIsCompleted(false);
            todo.setIsRolledOver(true);

            todoRepository.save(todo);
            count++;
        }
    }

    private void rollForwardIncompleteTodos(User user, LocalDate currentDate) {
        // Find all incomplete todos before current date
        List<Todo> incompleteTodos = todoRepository.findIncompleteBeforeDate(user.getId(), currentDate);

        // Start at -999 to place rolled-over todos at the top (after materialized virtuals at -1000)
        int basePosition = -999;
        int offset = 0;

        for (Todo todo : incompleteTodos) {
            todo.setAssignedDate(currentDate);
            todo.setIsRolledOver(true);
            todo.setPosition(basePosition - offset);
            todoRepository.save(todo);
            offset++;
        }
    }

    public boolean shouldTriggerRollover(Long userId, LocalDate requestedDate, LocalDate currentDate) {
        // Only rollover if requesting current date
        if (!requestedDate.equals(currentDate)) {
            return false;
        }

        // Check if we've already done rollover for this date
        LocalDate lastRollover = lastRolloverDateMap.get(userId);
        return lastRollover == null || !lastRollover.equals(currentDate);
    }

    // Helper class for tracking virtual instances to materialize
    private static class VirtualInstanceToMaterialize {
        RecurringTodo recurringTodo;
        LocalDate instanceDate;

        VirtualInstanceToMaterialize(RecurringTodo recurringTodo, LocalDate instanceDate) {
            this.recurringTodo = recurringTodo;
            this.instanceDate = instanceDate;
        }
    }
}
