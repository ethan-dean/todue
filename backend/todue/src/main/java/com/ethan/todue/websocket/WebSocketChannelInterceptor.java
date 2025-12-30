package com.ethan.todue.websocket;

import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.stereotype.Component;

import java.security.Principal;

/**
 * WebSocket channel interceptor that ensures users can only subscribe to their own channels.
 * Validates SUBSCRIBE commands to prevent unauthorized access to other users' updates.
 */
@Component
public class WebSocketChannelInterceptor implements ChannelInterceptor {

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);

        if (accessor != null && StompCommand.SUBSCRIBE.equals(accessor.getCommand())) {
            // Get destination (e.g., "/user/123/queue/updates")
            String destination = accessor.getDestination();

            // Get authenticated user ID from session attributes
            Long authenticatedUserId = (Long) accessor.getSessionAttributes().get("userId");

            if (destination != null && authenticatedUserId != null) {
                // Extract user ID from destination
                // Expected format: /user/{userId}/queue/updates
                if (destination.startsWith("/user/")) {
                    String[] parts = destination.split("/");
                    if (parts.length >= 3) {
                        try {
                            Long requestedUserId = Long.parseLong(parts[2]);

                            // Verify user is subscribing to their own channel
                            if (!requestedUserId.equals(authenticatedUserId)) {
                                System.err.println("WebSocket security violation: User " + authenticatedUserId +
                                        " attempted to subscribe to user " + requestedUserId + "'s channel");

                                // Throw exception - Spring will convert to ERROR frame
                                throw new org.springframework.messaging.MessageDeliveryException(
                                    "Cannot subscribe to another user's channel"
                                );
                            }

                            System.out.println("WebSocket subscribe: User " + authenticatedUserId + " subscribed to " + destination);
                        } catch (NumberFormatException e) {
                            System.err.println("WebSocket error: Invalid user ID in destination " + destination);

                            throw new org.springframework.messaging.MessageDeliveryException(
                                "Invalid destination format"
                            );
                        }
                    }
                }
            } else if (destination != null && destination.startsWith("/user/")) {
                // User trying to subscribe to a user-specific channel without authentication
                System.err.println("WebSocket error: Unauthenticated subscription attempt to " + destination);

                throw new org.springframework.messaging.MessageDeliveryException(
                    "Authentication required for user channels"
                );
            }

            // Set user principal for Spring's user destination resolution
            if (authenticatedUserId != null) {
                Principal principal = () -> authenticatedUserId.toString();
                accessor.setUser(principal);
            }
        } else if (accessor != null && StompCommand.CONNECT.equals(accessor.getCommand())) {
            // Set user principal on CONNECT as well
            Long authenticatedUserId = (Long) accessor.getSessionAttributes().get("userId");
            if (authenticatedUserId != null) {
                Principal principal = () -> authenticatedUserId.toString();
                accessor.setUser(principal);
                System.out.println("WebSocket CONNECT: User " + authenticatedUserId + " connected");
            }
        }

        return message;
    }
}
