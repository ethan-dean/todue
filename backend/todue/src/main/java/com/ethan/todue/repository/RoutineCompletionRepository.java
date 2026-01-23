package com.ethan.todue.repository;

import com.ethan.todue.model.RoutineCompletion;
import com.ethan.todue.model.RoutineCompletionStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface RoutineCompletionRepository extends JpaRepository<RoutineCompletion, Long> {

    @Query("SELECT c FROM RoutineCompletion c WHERE c.routine.id = :routineId AND c.status = 'IN_PROGRESS' ORDER BY c.startedAt DESC")
    Optional<RoutineCompletion> findActiveByRoutineId(@Param("routineId") Long routineId);

    @Query("SELECT c FROM RoutineCompletion c WHERE c.user.id = :userId AND c.status = 'IN_PROGRESS' ORDER BY c.startedAt DESC")
    List<RoutineCompletion> findActiveByUserId(@Param("userId") Long userId);

    @Query("SELECT c FROM RoutineCompletion c WHERE c.routine.id = :routineId AND c.date = :date")
    Optional<RoutineCompletion> findByRoutineIdAndDate(@Param("routineId") Long routineId, @Param("date") LocalDate date);

    @Query("SELECT c FROM RoutineCompletion c WHERE c.routine.id = :routineId AND c.date BETWEEN :startDate AND :endDate ORDER BY c.date ASC")
    List<RoutineCompletion> findByRoutineIdAndDateRange(
        @Param("routineId") Long routineId,
        @Param("startDate") LocalDate startDate,
        @Param("endDate") LocalDate endDate
    );

    @Query("SELECT c FROM RoutineCompletion c WHERE c.routine.id = :routineId AND c.status = :status AND c.date BETWEEN :startDate AND :endDate ORDER BY c.date ASC")
    List<RoutineCompletion> findByRoutineIdAndStatusAndDateRange(
        @Param("routineId") Long routineId,
        @Param("status") RoutineCompletionStatus status,
        @Param("startDate") LocalDate startDate,
        @Param("endDate") LocalDate endDate
    );

    @Query("SELECT COUNT(c) FROM RoutineCompletion c WHERE c.routine.id = :routineId AND c.status = :status")
    Long countByRoutineIdAndStatus(@Param("routineId") Long routineId, @Param("status") RoutineCompletionStatus status);

    @Query("SELECT COUNT(c) FROM RoutineCompletion c WHERE c.routine.id = :routineId AND c.status = :status AND c.date BETWEEN :startDate AND :endDate")
    Long countByRoutineIdAndStatusAndDateRange(
        @Param("routineId") Long routineId,
        @Param("status") RoutineCompletionStatus status,
        @Param("startDate") LocalDate startDate,
        @Param("endDate") LocalDate endDate
    );

    @Query("SELECT c FROM RoutineCompletion c WHERE c.routine.id = :routineId AND c.status = 'COMPLETED' ORDER BY c.date DESC")
    List<RoutineCompletion> findCompletedByRoutineIdOrderByDateDesc(@Param("routineId") Long routineId);

    boolean existsByRoutineIdAndDate(Long routineId, LocalDate date);

    @Query("SELECT CASE WHEN COUNT(c) > 0 THEN true ELSE false END FROM RoutineCompletion c WHERE c.routine.id = :routineId AND c.date = :date AND c.status = 'COMPLETED'")
    boolean existsCompletedByRoutineIdAndDate(@Param("routineId") Long routineId, @Param("date") LocalDate date);
}
