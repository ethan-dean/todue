package com.ethan.todue.repository;

import com.ethan.todue.model.RoutineStepCompletion;
import com.ethan.todue.model.RoutineStepCompletionStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RoutineStepCompletionRepository extends JpaRepository<RoutineStepCompletion, Long> {

    @Query("SELECT sc FROM RoutineStepCompletion sc WHERE sc.completion.id = :completionId ORDER BY sc.step.position ASC")
    List<RoutineStepCompletion> findByCompletionIdOrderByStepPosition(@Param("completionId") Long completionId);

    @Query("SELECT sc FROM RoutineStepCompletion sc WHERE sc.completion.id = :completionId AND sc.step.id = :stepId")
    Optional<RoutineStepCompletion> findByCompletionIdAndStepId(@Param("completionId") Long completionId, @Param("stepId") Long stepId);

    @Query("SELECT COUNT(sc) FROM RoutineStepCompletion sc WHERE sc.completion.id = :completionId AND sc.status = :status")
    Long countByCompletionIdAndStatus(@Param("completionId") Long completionId, @Param("status") RoutineStepCompletionStatus status);

    @Query("SELECT COUNT(sc) FROM RoutineStepCompletion sc WHERE sc.completion.id = :completionId AND sc.status != 'PENDING'")
    Long countCompletedOrSkippedByCompletionId(@Param("completionId") Long completionId);

    void deleteByCompletionId(Long completionId);
}
