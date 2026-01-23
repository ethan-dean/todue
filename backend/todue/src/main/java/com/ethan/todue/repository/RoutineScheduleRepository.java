package com.ethan.todue.repository;

import com.ethan.todue.model.RoutineSchedule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RoutineScheduleRepository extends JpaRepository<RoutineSchedule, Long> {

    @Query("SELECT s FROM RoutineSchedule s WHERE s.routine.id = :routineId ORDER BY s.dayOfWeek ASC")
    List<RoutineSchedule> findByRoutineIdOrderByDayOfWeek(@Param("routineId") Long routineId);

    @Query("SELECT s FROM RoutineSchedule s WHERE s.routine.id = :routineId AND s.dayOfWeek = :dayOfWeek")
    Optional<RoutineSchedule> findByRoutineIdAndDayOfWeek(@Param("routineId") Long routineId, @Param("dayOfWeek") Integer dayOfWeek);

    @Modifying
    @Query("DELETE FROM RoutineSchedule s WHERE s.routine.id = :routineId")
    void deleteByRoutineId(@Param("routineId") Long routineId);

    @Query("SELECT DISTINCT s.routine.id FROM RoutineSchedule s WHERE s.routine.user.id = :userId AND s.dayOfWeek = :dayOfWeek AND s.promptTime IS NOT NULL")
    List<Long> findRoutineIdsWithScheduleForDay(@Param("userId") Long userId, @Param("dayOfWeek") Integer dayOfWeek);
}
