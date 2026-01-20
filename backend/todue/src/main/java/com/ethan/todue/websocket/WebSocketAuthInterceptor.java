package com.ethan.todue.websocket;

import com.ethan.todue.model.User;
import com.ethan.todue.repository.UserRepository;
import com.ethan.todue.security.JwtUtil;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.http.server.ServletServerHttpRequest;
import org.springframework.http.server.ServletServerHttpResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.server.HandshakeInterceptor;

import java.util.Map;

/**
 * WebSocket handshake interceptor that extracts and validates JWT token.
 * Adds authenticated user information to WebSocket session attributes.
 */
@Component
public class WebSocketAuthInterceptor implements HandshakeInterceptor {

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private UserRepository userRepository;

    @Override
    public boolean beforeHandshake(
            ServerHttpRequest request,
            ServerHttpResponse response,
            WebSocketHandler wsHandler,
            Map<String, Object> attributes
    ) throws Exception {
        // Extract token from query parameter
        if (request instanceof ServletServerHttpRequest) {
            ServletServerHttpRequest servletRequest = (ServletServerHttpRequest) request;
            String token = servletRequest.getServletRequest().getParameter("token");

            if (token != null && !token.isEmpty()) {
                try {
                    // Validate token
                    if (jwtUtil.validateToken(token)) {
                        // Extract email from token
                        String email = jwtUtil.getEmailFromToken(token);

                        // Look up user
                        User user = userRepository.findByEmail(email).orElse(null);

                        if (user != null) {
                            // Store user ID and email in session attributes
                            attributes.put("userId", user.getId());
                            attributes.put("email", email);
                            System.out.println("WebSocket handshake: authenticated user " + user.getId() + " (" + email + ")");
                            return true; // Allow connection
                        } else {
                            System.err.println("WebSocket handshake: user not found for email " + email);
                        }
                    } else {
                        System.err.println("WebSocket handshake: invalid token");
                    }
                } catch (Exception e) {
                    System.err.println("WebSocket handshake: token validation failed - " + e.getMessage());
                }
            } else {
                System.err.println("WebSocket handshake: no token provided");
            }
        }

        // Reject connection if authentication failed
        if (response instanceof ServletServerHttpResponse) {
            ((ServletServerHttpResponse) response).getServletResponse().setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        }
        return false;
    }

    @Override
    public void afterHandshake(
            ServerHttpRequest request,
            ServerHttpResponse response,
            WebSocketHandler wsHandler,
            Exception exception
    ) {
        // Nothing to do after handshake
    }
}
