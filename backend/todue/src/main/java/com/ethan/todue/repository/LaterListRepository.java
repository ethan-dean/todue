package com.ethan.todue.repository;

import com.ethan.todue.model.LaterList;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface LaterListRepository extends JpaRepository<LaterList, Long> {

    @Query("SELECT l FROM LaterList l WHERE l.user.id = :userId ORDER BY l.listName ASC")
    List<LaterList> findByUserIdOrderByListName(@Param("userId") Long userId);

    @Query("SELECT l FROM LaterList l WHERE l.user.id = :userId AND l.listName = :listName")
    Optional<LaterList> findByUserIdAndListName(@Param("userId") Long userId, @Param("listName") String listName);

    boolean existsByUserIdAndListName(Long userId, String listName);
}
