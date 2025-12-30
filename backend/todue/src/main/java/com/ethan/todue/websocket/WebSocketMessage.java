package com.ethan.todue.websocket;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class WebSocketMessage<T> {
    private WebSocketMessageType type;
    private T data;
    private Instant timestamp;

    public WebSocketMessage(WebSocketMessageType type, T data) {
        this.type = type;
        this.data = data;
        this.timestamp = Instant.now();
    }
}
