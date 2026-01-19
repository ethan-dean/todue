package com.ethan.todue.service;

import com.ethan.todue.dto.LaterListResponse;
import com.ethan.todue.dto.LaterListTodoResponse;
import com.ethan.todue.model.LaterList;
import com.ethan.todue.model.LaterListTodo;
import com.ethan.todue.model.User;
import com.ethan.todue.repository.LaterListRepository;
import com.ethan.todue.repository.LaterListTodoRepository;
import com.ethan.todue.websocket.WebSocketService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class LaterListService {

    @Autowired
    private LaterListRepository laterListRepository;

    @Autowired
    private LaterListTodoRepository laterListTodoRepository;

    @Autowired
    private UserService userService;

    @Autowired
    private WebSocketService webSocketService;

    // ==================== List Operations ====================

    public List<LaterListResponse> getAllLists() {
        User user = userService.getCurrentUser();
        return laterListRepository.findByUserIdOrderByListName(user.getId())
                .stream()
                .map(this::toListResponse)
                .collect(Collectors.toList());
    }

    @Transactional
    public LaterListResponse createList(String listName) {
        User user = userService.getCurrentUser();

        // Check for duplicate name
        if (laterListRepository.existsByUserIdAndListName(user.getId(), listName)) {
            throw new RuntimeException("A list with this name already exists");
        }

        LaterList list = new LaterList();
        list.setUser(user);
        list.setListName(listName);

        list = laterListRepository.save(list);
        LaterListResponse response = toListResponse(list);

        webSocketService.notifyLaterListChanged(user.getId(), list.getId(), "LIST_CREATED");

        return response;
    }

    @Transactional
    public LaterListResponse updateListName(Long listId, String newName) {
        LaterList list = getListAndVerifyOwnership(listId);
        Long userId = list.getUser().getId();

        // Check for duplicate name (excluding current list)
        if (laterListRepository.existsByUserIdAndListName(userId, newName) &&
            !list.getListName().equals(newName)) {
            throw new RuntimeException("A list with this name already exists");
        }

        list.setListName(newName);
        list = laterListRepository.save(list);
        LaterListResponse response = toListResponse(list);

        webSocketService.notifyLaterListChanged(userId, listId, "LIST_UPDATED");

        return response;
    }

    @Transactional
    public void deleteList(Long listId) {
        LaterList list = getListAndVerifyOwnership(listId);
        Long userId = list.getUser().getId();

        laterListRepository.delete(list);

        webSocketService.notifyLaterListChanged(userId, listId, "LIST_DELETED");
    }

    // ==================== Todo Operations ====================

    public List<LaterListTodoResponse> getTodosForList(Long listId) {
        LaterList list = getListAndVerifyOwnership(listId);

        return laterListTodoRepository.findByListIdOrderByPosition(listId)
                .stream()
                .map(this::toTodoResponse)
                .collect(Collectors.toList());
    }

    @Transactional
    public LaterListTodoResponse createTodo(Long listId, String text, Integer position) {
        LaterList list = getListAndVerifyOwnership(listId);
        Long userId = list.getUser().getId();

        LaterListTodo todo = new LaterListTodo();
        todo.setList(list);
        todo.setText(text);
        todo.setIsCompleted(false);

        if (position != null) {
            // Shift existing items
            laterListTodoRepository.incrementPositions(listId, position);
            todo.setPosition(position);
        } else {
            // Add to end
            Integer maxPosition = laterListTodoRepository.findMaxPosition(listId);
            todo.setPosition(maxPosition + 1);
        }

        todo = laterListTodoRepository.save(todo);
        LaterListTodoResponse response = toTodoResponse(todo);

        webSocketService.notifyLaterListChanged(userId, listId, "TODOS_UPDATED");

        return response;
    }

    @Transactional
    public LaterListTodoResponse updateTodoText(Long listId, Long todoId, String newText) {
        LaterListTodo todo = getTodoAndVerifyOwnership(listId, todoId);
        Long userId = todo.getList().getUser().getId();

        todo.setText(newText);
        todo = laterListTodoRepository.save(todo);
        LaterListTodoResponse response = toTodoResponse(todo);

        webSocketService.notifyLaterListChanged(userId, listId, "TODOS_UPDATED");

        return response;
    }

    @Transactional
    public LaterListTodoResponse updateTodoPosition(Long listId, Long todoId, Integer newPosition) {
        LaterListTodo todo = getTodoAndVerifyOwnership(listId, todoId);
        Long userId = todo.getList().getUser().getId();

        // Get all todos sorted by position
        List<LaterListTodo> allTodos = laterListTodoRepository.findByListIdOrderByPosition(listId);

        // Find current index
        int oldIndex = -1;
        for (int i = 0; i < allTodos.size(); i++) {
            if (allTodos.get(i).getId().equals(todoId)) {
                oldIndex = i;
                break;
            }
        }

        if (oldIndex == -1) {
            throw new RuntimeException("Todo not found in list");
        }

        // Remove from old position, insert at new position
        LaterListTodo movedTodo = allTodos.remove(oldIndex);
        allTodos.add(newPosition, movedTodo);

        // Only renumber the affected range
        int startIdx = Math.min(oldIndex, newPosition);
        int endIdx = Math.max(oldIndex, newPosition);

        List<LaterListTodo> affectedTodos = new ArrayList<>();
        for (int i = startIdx; i <= endIdx; i++) {
            allTodos.get(i).setPosition(i + 1);
            affectedTodos.add(allTodos.get(i));
        }

        laterListTodoRepository.saveAll(affectedTodos);
        LaterListTodoResponse response = toTodoResponse(todo);

        webSocketService.notifyLaterListChanged(userId, listId, "TODOS_UPDATED");

        return response;
    }

    @Transactional
    public LaterListTodoResponse completeTodo(Long listId, Long todoId) {
        LaterListTodo todo = getTodoAndVerifyOwnership(listId, todoId);
        Long userId = todo.getList().getUser().getId();

        // Get all todos for this list, sorted by position
        List<LaterListTodo> allTodos = laterListTodoRepository.findByListIdOrderByPosition(listId);

        // Find current index
        int oldIndex = -1;
        for (int i = 0; i < allTodos.size(); i++) {
            if (allTodos.get(i).getId().equals(todoId)) {
                oldIndex = i;
                break;
            }
        }

        if (oldIndex == -1) {
            throw new RuntimeException("Todo not found in list");
        }

        // Find first completed todo position (or end if none)
        int firstCompletedIndex = allTodos.size();
        for (int i = 0; i < allTodos.size(); i++) {
            if (allTodos.get(i).getIsCompleted()) {
                firstCompletedIndex = i;
                break;
            }
        }

        // Mark as completed
        todo.setIsCompleted(true);
        todo.setCompletedAt(Instant.now());

        // Move to top of completed section
        LaterListTodo movedTodo = allTodos.remove(oldIndex);
        int newIndex = firstCompletedIndex > oldIndex ? firstCompletedIndex - 1 : firstCompletedIndex;
        allTodos.add(newIndex, movedTodo);

        // Renumber affected range
        int startIdx = Math.min(oldIndex, newIndex);
        int endIdx = Math.max(oldIndex, newIndex);

        List<LaterListTodo> affectedTodos = new ArrayList<>();
        for (int i = startIdx; i <= endIdx; i++) {
            allTodos.get(i).setPosition(i + 1);
            affectedTodos.add(allTodos.get(i));
        }

        laterListTodoRepository.saveAll(affectedTodos);
        LaterListTodoResponse response = toTodoResponse(todo);

        webSocketService.notifyLaterListChanged(userId, listId, "TODOS_UPDATED");

        return response;
    }

    @Transactional
    public LaterListTodoResponse uncompleteTodo(Long listId, Long todoId) {
        LaterListTodo todo = getTodoAndVerifyOwnership(listId, todoId);
        Long userId = todo.getList().getUser().getId();

        // Get all todos for this list, sorted by position
        List<LaterListTodo> allTodos = laterListTodoRepository.findByListIdOrderByPosition(listId);

        // Find current index
        int oldIndex = -1;
        for (int i = 0; i < allTodos.size(); i++) {
            if (allTodos.get(i).getId().equals(todoId)) {
                oldIndex = i;
                break;
            }
        }

        if (oldIndex == -1) {
            throw new RuntimeException("Todo not found in list");
        }

        // Find first completed todo position (end of incomplete section)
        int firstCompletedIndex = allTodos.size();
        for (int i = 0; i < allTodos.size(); i++) {
            if (allTodos.get(i).getIsCompleted() && !allTodos.get(i).getId().equals(todoId)) {
                firstCompletedIndex = i;
                break;
            }
        }

        // Mark as incomplete
        todo.setIsCompleted(false);
        todo.setCompletedAt(null);

        // Move to end of incomplete section
        LaterListTodo movedTodo = allTodos.remove(oldIndex);
        int newIndex = firstCompletedIndex > oldIndex ? firstCompletedIndex - 1 : firstCompletedIndex;
        allTodos.add(newIndex, movedTodo);

        // Renumber affected range
        int startIdx = Math.min(oldIndex, newIndex);
        int endIdx = Math.max(oldIndex, newIndex);

        List<LaterListTodo> affectedTodos = new ArrayList<>();
        for (int i = startIdx; i <= endIdx; i++) {
            allTodos.get(i).setPosition(i + 1);
            affectedTodos.add(allTodos.get(i));
        }

        laterListTodoRepository.saveAll(affectedTodos);
        LaterListTodoResponse response = toTodoResponse(todo);

        webSocketService.notifyLaterListChanged(userId, listId, "TODOS_UPDATED");

        return response;
    }

    @Transactional
    public void deleteTodo(Long listId, Long todoId) {
        LaterListTodo todo = getTodoAndVerifyOwnership(listId, todoId);
        Long userId = todo.getList().getUser().getId();

        laterListTodoRepository.delete(todo);

        webSocketService.notifyLaterListChanged(userId, listId, "TODOS_UPDATED");
    }

    // ==================== Helper Methods ====================

    private LaterList getListAndVerifyOwnership(Long listId) {
        LaterList list = laterListRepository.findById(listId)
                .orElseThrow(() -> new RuntimeException("List not found"));

        User currentUser = userService.getCurrentUser();
        if (!list.getUser().getId().equals(currentUser.getId())) {
            throw new RuntimeException("Unauthorized access to list");
        }

        return list;
    }

    private LaterListTodo getTodoAndVerifyOwnership(Long listId, Long todoId) {
        // First verify list ownership
        LaterList list = getListAndVerifyOwnership(listId);

        LaterListTodo todo = laterListTodoRepository.findById(todoId)
                .orElseThrow(() -> new RuntimeException("Todo not found"));

        // Verify todo belongs to the specified list
        if (!todo.getList().getId().equals(listId)) {
            throw new RuntimeException("Todo does not belong to this list");
        }

        return todo;
    }

    private LaterListResponse toListResponse(LaterList list) {
        return new LaterListResponse(
                list.getId(),
                list.getListName()
        );
    }

    private LaterListTodoResponse toTodoResponse(LaterListTodo todo) {
        return new LaterListTodoResponse(
                todo.getId(),
                todo.getText(),
                todo.getIsCompleted(),
                todo.getCompletedAt(),
                todo.getPosition()
        );
    }
}
