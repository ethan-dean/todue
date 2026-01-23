package com.ethan.todue.repository;

import com.ethan.todue.model.RoutinePromptDismissal;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface RoutinePromptDismissalRepository extends JpaRepository<RoutinePromptDismissal, Long> {

    boolean existsByUserIdAndRoutineIdAndDismissedDate(Long userId, Long routineId, LocalDate dismissedDate);

    @Query("SELECT d.routine.id FROM RoutinePromptDismissal d WHERE d.user.id = :userId AND d.dismissedDate = :date")
    List<Long> findDismissedRoutineIdsByUserIdAndDate(@Param("userId") Long userId, @Param("date") LocalDate date);

    void deleteByDismissedDateBefore(LocalDate date);
}
