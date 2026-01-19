package com.ethan.todue.repository;

import com.ethan.todue.model.LaterListTodo;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface LaterListTodoRepository extends JpaRepository<LaterListTodo, Long> {

    @Query("SELECT t FROM LaterListTodo t WHERE t.list.id = :listId ORDER BY t.position ASC")
    List<LaterListTodo> findByListIdOrderByPosition(@Param("listId") Long listId);

    @Modifying
    @Query("UPDATE LaterListTodo t SET t.position = t.position + 1 WHERE t.list.id = :listId AND t.position >= :position")
    void incrementPositions(@Param("listId") Long listId, @Param("position") Integer position);

    @Query("SELECT COALESCE(MAX(t.position), 0) FROM LaterListTodo t WHERE t.list.id = :listId")
    Integer findMaxPosition(@Param("listId") Long listId);
}
