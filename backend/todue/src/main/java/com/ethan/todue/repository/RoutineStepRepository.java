package com.ethan.todue.repository;

import com.ethan.todue.model.RoutineStep;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface RoutineStepRepository extends JpaRepository<RoutineStep, Long> {

    @Query("SELECT s FROM RoutineStep s WHERE s.routine.id = :routineId ORDER BY s.position ASC")
    List<RoutineStep> findByRoutineIdOrderByPosition(@Param("routineId") Long routineId);

    @Query("SELECT COALESCE(MAX(s.position), 0) FROM RoutineStep s WHERE s.routine.id = :routineId")
    Integer findMaxPosition(@Param("routineId") Long routineId);

    @Modifying
    @Query("UPDATE RoutineStep s SET s.position = s.position + 1 WHERE s.routine.id = :routineId AND s.position >= :position")
    void incrementPositions(@Param("routineId") Long routineId, @Param("position") Integer position);

    @Query("SELECT COUNT(s) FROM RoutineStep s WHERE s.routine.id = :routineId")
    Integer countByRoutineId(@Param("routineId") Long routineId);
}
