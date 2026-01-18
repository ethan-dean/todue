package com.ethan.todue.controller;

import com.ethan.todue.dto.CreateTodoRequest;
import com.ethan.todue.dto.TodoResponse;
import com.ethan.todue.dto.UpdateAssignedDateRequest;
import com.ethan.todue.dto.UpdateTodoPositionRequest;
import com.ethan.todue.dto.UpdateTodoTextRequest;
import com.ethan.todue.dto.VirtualTodoRequest;
import com.ethan.todue.service.TodoService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/todos")
public class TodoController {

    @Autowired
    private TodoService todoService;

    @PostMapping
    public ResponseEntity<TodoResponse> createTodo(@Valid @RequestBody CreateTodoRequest request) {
        TodoResponse response = todoService.createTodo(request.getText(), request.getAssignedDate(), request.getPosition());
        return ResponseEntity.ok(response);
    }

    @GetMapping
    public ResponseEntity<List<TodoResponse>> getTodos(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate
    ) {
        if (date != null) {
            return ResponseEntity.ok(todoService.getTodosForDate(date));
        } else if (startDate != null && endDate != null) {
            return ResponseEntity.ok(todoService.getTodosForDateRange(startDate, endDate));
        } else {
            return ResponseEntity.badRequest().build();
        }
    }

    @PutMapping("/{id}/text")
    public ResponseEntity<TodoResponse> updateTodoText(
            @PathVariable Long id,
            @Valid @RequestBody UpdateTodoTextRequest request
    ) {
        TodoResponse response = todoService.updateTodoText(id, request.getText());
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{id}/position")
    public ResponseEntity<TodoResponse> updateTodoPosition(
            @PathVariable Long id,
            @Valid @RequestBody UpdateTodoPositionRequest request
    ) {
        TodoResponse response = todoService.updateTodoPosition(id, request.getPosition());
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{id}/assigned-date")
    public ResponseEntity<TodoResponse> updateTodoAssignedDate(
            @PathVariable Long id,
            @Valid @RequestBody UpdateAssignedDateRequest request
    ) {
        TodoResponse response = todoService.updateTodoAssignedDate(id, request.getToDate());
        return ResponseEntity.ok(response);
    }

    @PostMapping("/{id}/complete")
    public ResponseEntity<TodoResponse> completeTodo(@PathVariable Long id) {
        TodoResponse response = todoService.completeTodo(id);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/{id}/uncomplete")
    public ResponseEntity<TodoResponse> uncompleteTodo(@PathVariable Long id) {
        TodoResponse response = todoService.uncompleteTodo(id);
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, String>> deleteTodo(
            @PathVariable Long id,
            @RequestParam(required = false) Boolean deleteAllFuture
    ) {
        todoService.deleteTodo(id, deleteAllFuture);
        return ResponseEntity.ok(Map.of("message", "Todo deleted successfully"));
    }

    // Virtual todo endpoints

    @PostMapping("/virtual/complete")
    public ResponseEntity<TodoResponse> completeVirtualTodo(@Valid @RequestBody VirtualTodoRequest request) {
        TodoResponse response = todoService.completeVirtualTodo(
                request.getRecurringTodoId(),
                request.getInstanceDate()
        );
        return ResponseEntity.ok(response);
    }

    @PostMapping("/virtual/update-text")
    public ResponseEntity<TodoResponse> updateVirtualTodoText(
            @Valid @RequestBody VirtualTodoRequest request,
            @RequestParam String text
    ) {
        TodoResponse response = todoService.updateVirtualTodoText(
                request.getRecurringTodoId(),
                request.getInstanceDate(),
                text
        );
        return ResponseEntity.ok(response);
    }

    @PostMapping("/virtual/update-position")
    public ResponseEntity<TodoResponse> updateVirtualTodoPosition(
            @Valid @RequestBody VirtualTodoRequest request,
            @RequestParam Integer position
    ) {
        TodoResponse response = todoService.updateVirtualTodoPosition(
                request.getRecurringTodoId(),
                request.getInstanceDate(),
                position
        );
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/virtual")
    public ResponseEntity<Map<String, String>> deleteVirtualTodo(
            @RequestParam Long recurringTodoId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate instanceDate,
            @RequestParam(required = false) Boolean deleteAllFuture
    ) {
        todoService.deleteVirtualTodo(recurringTodoId, instanceDate, deleteAllFuture);
        return ResponseEntity.ok(Map.of("message", "Virtual todo deleted successfully"));
    }

    @PostMapping("/virtual/update-assigned-date")
    public ResponseEntity<TodoResponse> updateVirtualTodoAssignedDate(
            @Valid @RequestBody VirtualTodoRequest request,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate
    ) {
        TodoResponse response = todoService.updateVirtualTodoAssignedDate(
                request.getRecurringTodoId(),
                request.getInstanceDate(),
                toDate
        );
        return ResponseEntity.ok(response);
    }
}
