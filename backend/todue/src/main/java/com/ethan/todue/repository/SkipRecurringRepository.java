package com.ethan.todue.repository;

import com.ethan.todue.model.SkipRecurring;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface SkipRecurringRepository extends JpaRepository<SkipRecurring, Long> {

    boolean existsByRecurringTodoIdAndSkipDate(Long recurringTodoId, LocalDate skipDate);

    List<SkipRecurring> findByRecurringTodoId(Long recurringTodoId);
}
