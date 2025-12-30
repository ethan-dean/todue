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
}
