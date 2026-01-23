package com.ethan.todue.websocket;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;

@Service
public class WebSocketService {

    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    public void sendToUser(Long userId, WebSocketMessage<?> message) {
        messagingTemplate.convertAndSendToUser(
                userId.toString(),
                "/queue/updates",
                message
        );
    }

    /**
     * Notify user that todos changed for a specific date.
     * Client should refetch todos for this date.
     *
     * Use for: create regular todo, complete todo, update text, reorder, delete single instance
     */
    public void notifyTodosChanged(Long userId, LocalDate date) {
        Map<String, Object> data = new HashMap<>();
        // Send date as string in ISO format (yyyy-MM-dd) for frontend compatibility
        data.put("date", date.toString());

        WebSocketMessage<Map<String, Object>> message = new WebSocketMessage<>(
                WebSocketMessageType.TODOS_CHANGED,
                data
        );
        sendToUser(userId, message);
    }

    /**
     * Notify user that a recurring pattern changed.
     * Client should refetch all currently visible dates.
     *
     * Use for: create recurring pattern, update recurring pattern, delete all future instances
     */
    public void notifyRecurringChanged(Long userId) {
        Map<String, Object> data = new HashMap<>();

        WebSocketMessage<Map<String, Object>> message = new WebSocketMessage<>(
                WebSocketMessageType.RECURRING_CHANGED,
                data
        );
        sendToUser(userId, message);
    }

    /**
     * Notify user that a later list changed.
     * Client should refetch that list's data.
     *
     * @param userId The user ID
     * @param listId The list ID that changed (null for list-level changes like create/delete)
     * @param action The type of change: LIST_UPDATED, TODOS_UPDATED, LIST_DELETED, LIST_CREATED
     */
    public void notifyLaterListChanged(Long userId, Long listId, String action) {
        Map<String, Object> data = new HashMap<>();
        if (listId != null) {
            data.put("listId", listId);
        }
        data.put("action", action);

        WebSocketMessage<Map<String, Object>> message = new WebSocketMessage<>(
                WebSocketMessageType.LATER_LIST_CHANGED,
                data
        );
        sendToUser(userId, message);
    }

    /**
     * Notify user that a routine changed.
     * Client should refetch routines or specific routine data.
     *
     * @param userId The user ID
     * @param routineId The routine ID that changed
     * @param action The type of change: ROUTINE_CREATED, ROUTINE_UPDATED, ROUTINE_DELETED,
     *               EXECUTION_STARTED, EXECUTION_COMPLETED, EXECUTION_ABANDONED, STEP_COMPLETED
     */
    public void notifyRoutineChanged(Long userId, Long routineId, String action) {
        Map<String, Object> data = new HashMap<>();
        if (routineId != null) {
            data.put("routineId", routineId);
        }
        data.put("action", action);

        WebSocketMessage<Map<String, Object>> message = new WebSocketMessage<>(
                WebSocketMessageType.ROUTINE_CHANGED,
                data
        );
        sendToUser(userId, message);
    }
}
