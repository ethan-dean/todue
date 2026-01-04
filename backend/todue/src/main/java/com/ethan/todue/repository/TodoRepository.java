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

    @Query("SELECT t FROM Todo t WHERE t.user.id = :userId AND t.assignedDate = :assignedDate " +
           "ORDER BY t.position ASC")
    List<Todo> findByUserIdAndAssignedDate(@Param("userId") Long userId, @Param("assignedDate") LocalDate assignedDate);

    @Query("SELECT t FROM Todo t WHERE t.user.id = :userId " +
           "AND t.assignedDate BETWEEN :startDate AND :endDate " +
           "ORDER BY t.assignedDate, t.position ASC")
    List<Todo> findByUserIdAndAssignedDateBetween(
        @Param("userId") Long userId,
        @Param("startDate") LocalDate startDate,
        @Param("endDate") LocalDate endDate
    );

    @Query("SELECT t FROM Todo t WHERE t.user.id = :userId " +
           "AND t.assignedDate < :date AND t.isCompleted = false " +
           "ORDER BY t.assignedDate DESC, t.position ASC")
    List<Todo> findIncompleteBeforeDate(@Param("userId") Long userId, @Param("date") LocalDate date);

    // Changed to findFirst to handle duplicates gracefully during cleanup period
    Optional<Todo> findFirstByRecurringTodoIdAndInstanceDate(Long recurringTodoId, LocalDate instanceDate);

    @Query("SELECT t FROM Todo t WHERE t.recurringTodo.id = :recurringTodoId " +
           "AND t.instanceDate > :afterDate AND t.isCompleted = false")
    List<Todo> findFutureIncompleteTodosForRecurring(
        @Param("recurringTodoId") Long recurringTodoId,
        @Param("afterDate") LocalDate afterDate
    );
}
