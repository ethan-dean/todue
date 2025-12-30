package com.ethan.todue.repository;

import com.ethan.todue.model.Todo;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface TodoRepository extends JpaRepository<Todo, Long> {

    List<Todo> findByUserIdAndAssignedDate(Long userId, LocalDate assignedDate);

    @Query("SELECT t FROM Todo t WHERE t.user.id = :userId " +
           "AND t.assignedDate BETWEEN :startDate AND :endDate " +
           "ORDER BY t.assignedDate, t.isRolledOver DESC, t.position ASC, t.id ASC")
    List<Todo> findByUserIdAndAssignedDateBetween(
        @Param("userId") Long userId,
        @Param("startDate") LocalDate startDate,
        @Param("endDate") LocalDate endDate
    );

    @Query("SELECT t FROM Todo t WHERE t.user.id = :userId " +
           "AND t.assignedDate < :date AND t.isCompleted = false")
    List<Todo> findIncompleteBeforeDate(@Param("userId") Long userId, @Param("date") LocalDate date);

    Optional<Todo> findByRecurringTodoIdAndInstanceDate(Long recurringTodoId, LocalDate instanceDate);

    @Query("SELECT t FROM Todo t WHERE t.recurringTodo.id = :recurringTodoId " +
           "AND t.instanceDate > :afterDate AND t.isCompleted = false")
    List<Todo> findFutureIncompleteTodosForRecurring(
        @Param("recurringTodoId") Long recurringTodoId,
        @Param("afterDate") LocalDate afterDate
    );
}
