package com.ethan.todue.repository;

import com.ethan.todue.model.Routine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RoutineRepository extends JpaRepository<Routine, Long> {

    @Query("SELECT r FROM Routine r WHERE r.user.id = :userId ORDER BY r.name ASC")
    List<Routine> findByUserIdOrderByName(@Param("userId") Long userId);

    @Query("SELECT r FROM Routine r WHERE r.user.id = :userId AND r.name = :name")
    Optional<Routine> findByUserIdAndName(@Param("userId") Long userId, @Param("name") String name);

    boolean existsByUserIdAndName(Long userId, String name);
}
