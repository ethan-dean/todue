package com.ethan.todue.websocket;

public enum WebSocketMessageType {
    TODOS_CHANGED,      // Single date changed - refetch that date
    RECURRING_CHANGED   // Recurring pattern changed - refetch all visible dates
}
