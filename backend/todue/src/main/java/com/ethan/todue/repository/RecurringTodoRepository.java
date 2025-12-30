package com.ethan.todue.repository;

import com.ethan.todue.model.RecurringTodo;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface RecurringTodoRepository extends JpaRepository<RecurringTodo, Long> {

    List<RecurringTodo> findByUserId(Long userId);

    @Query("SELECT r FROM RecurringTodo r WHERE r.user.id = :userId " +
           "AND (r.endDate IS NULL OR r.endDate >= :date)")
    List<RecurringTodo> findActiveByUserIdAndDate(@Param("userId") Long userId, @Param("date") LocalDate date);
}
