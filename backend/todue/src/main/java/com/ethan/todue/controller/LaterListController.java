package com.ethan.todue.controller;

import com.ethan.todue.dto.*;
import com.ethan.todue.service.LaterListService;
import com.ethan.todue.util.DeadlockRetry;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/later-lists")
public class LaterListController {

    @Autowired
    private LaterListService laterListService;

    // ==================== List Endpoints ====================

    @GetMapping
    public ResponseEntity<List<LaterListResponse>> getAllLists() {
        List<LaterListResponse> lists = laterListService.getAllLists();
        return ResponseEntity.ok(lists);
    }

    @PostMapping
    public ResponseEntity<LaterListResponse> createList(@Valid @RequestBody CreateLaterListRequest request) {
        LaterListResponse response = DeadlockRetry.execute(() -> laterListService.createList(request.getListName()));
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{id}/name")
    public ResponseEntity<LaterListResponse> updateListName(
            @PathVariable Long id,
            @Valid @RequestBody UpdateLaterListNameRequest request
    ) {
        LaterListResponse response = DeadlockRetry.execute(() -> laterListService.updateListName(id, request.getListName()));
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, String>> deleteList(@PathVariable Long id) {
        DeadlockRetry.executeVoid(() -> laterListService.deleteList(id));
        return ResponseEntity.ok(Map.of("message", "List deleted successfully"));
    }

    // ==================== Todo Endpoints ====================

    @GetMapping("/{listId}/todos")
    public ResponseEntity<List<LaterListTodoResponse>> getTodosForList(@PathVariable Long listId) {
        List<LaterListTodoResponse> todos = laterListService.getTodosForList(listId);
        return ResponseEntity.ok(todos);
    }

    @PostMapping("/{listId}/todos")
    public ResponseEntity<LaterListTodoResponse> createTodo(
            @PathVariable Long listId,
            @Valid @RequestBody CreateLaterListTodoRequest request
    ) {
        LaterListTodoResponse response = DeadlockRetry.execute(() -> laterListService.createTodo(
                listId,
                request.getText(),
                request.getPosition()
        ));
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{listId}/todos/{id}/text")
    public ResponseEntity<LaterListTodoResponse> updateTodoText(
            @PathVariable Long listId,
            @PathVariable Long id,
            @Valid @RequestBody UpdateLaterListTodoTextRequest request
    ) {
        LaterListTodoResponse response = DeadlockRetry.execute(() -> laterListService.updateTodoText(listId, id, request.getText()));
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{listId}/todos/{id}/position")
    public ResponseEntity<LaterListTodoResponse> updateTodoPosition(
            @PathVariable Long listId,
            @PathVariable Long id,
            @Valid @RequestBody UpdateLaterListTodoPositionRequest request
    ) {
        LaterListTodoResponse response = DeadlockRetry.execute(() -> laterListService.updateTodoPosition(listId, id, request.getPosition()));
        return ResponseEntity.ok(response);
    }

    @PostMapping("/{listId}/todos/{id}/complete")
    public ResponseEntity<LaterListTodoResponse> completeTodo(
            @PathVariable Long listId,
            @PathVariable Long id
    ) {
        LaterListTodoResponse response = DeadlockRetry.execute(() -> laterListService.completeTodo(listId, id));
        return ResponseEntity.ok(response);
    }

    @PostMapping("/{listId}/todos/{id}/uncomplete")
    public ResponseEntity<LaterListTodoResponse> uncompleteTodo(
            @PathVariable Long listId,
            @PathVariable Long id
    ) {
        LaterListTodoResponse response = DeadlockRetry.execute(() -> laterListService.uncompleteTodo(listId, id));
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/{listId}/todos/{id}")
    public ResponseEntity<Map<String, String>> deleteTodo(
            @PathVariable Long listId,
            @PathVariable Long id
    ) {
        DeadlockRetry.executeVoid(() -> laterListService.deleteTodo(listId, id));
        return ResponseEntity.ok(Map.of("message", "Todo deleted successfully"));
    }
}
