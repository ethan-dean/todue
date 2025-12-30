package com.ethan.todue.service;

import com.ethan.todue.model.RecurringTodo;
import com.ethan.todue.model.SkipRecurring;
import com.ethan.todue.repository.RecurringTodoRepository;
import com.ethan.todue.repository.SkipRecurringRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

@Service
public class SkipRecurringService {

    @Autowired
    private SkipRecurringRepository skipRecurringRepository;

    @Autowired
    private RecurringTodoRepository recurringTodoRepository;

    @Autowired
    private UserService userService;

    @Transactional
    public void skipInstance(Long recurringTodoId, LocalDate skipDate) {
        // Verify ownership
        RecurringTodo recurringTodo = recurringTodoRepository.findById(recurringTodoId)
                .orElseThrow(() -> new RuntimeException("Recurring todo not found"));

        if (!recurringTodo.getUser().getId().equals(userService.getCurrentUser().getId())) {
            throw new RuntimeException("Unauthorized access");
        }

        // Check if already skipped
        if (!skipRecurringRepository.existsByRecurringTodoIdAndSkipDate(recurringTodoId, skipDate)) {
            SkipRecurring skipRecurring = new SkipRecurring();
            skipRecurring.setRecurringTodo(recurringTodo);
            skipRecurring.setSkipDate(skipDate);
            skipRecurringRepository.save(skipRecurring);
        }
    }

    public boolean isInstanceSkipped(Long recurringTodoId, LocalDate date) {
        return skipRecurringRepository.existsByRecurringTodoIdAndSkipDate(recurringTodoId, date);
    }
}
