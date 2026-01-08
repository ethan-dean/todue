package com.ethan.todue.controller;

import com.ethan.todue.dto.UserResponse;
import com.ethan.todue.model.User;
import com.ethan.todue.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.Map;

@RestController
@RequestMapping("/api/user")
public class UserController {

    @Autowired
    private UserService userService;

    @GetMapping("/me")
    public ResponseEntity<UserResponse> getCurrentUser() {
        User user = userService.getCurrentUser();
        UserResponse response = new UserResponse(
            user.getId(),
            user.getEmail(),
            user.getTimezone(),
            user.getCreatedAt().toString(),
            user.getLastRolloverDate() != null ? user.getLastRolloverDate().toString() : null,
            user.getUpdatedAt().toString()
        );
        return ResponseEntity.ok(response);
    }

    @GetMapping("/current-date")
    public ResponseEntity<Map<String, LocalDate>> getCurrentDate() {
        LocalDate currentDate = userService.getCurrentDateForUser();
        return ResponseEntity.ok(Map.of("currentDate", currentDate));
    }

    @PutMapping("/timezone")
    public ResponseEntity<UserResponse> updateTimezone(@RequestBody Map<String, String> request) {
        String timezone = request.get("timezone");
        User user = userService.updateTimezone(timezone);
        UserResponse response = new UserResponse(
            user.getId(),
            user.getEmail(),
            user.getTimezone(),
            user.getCreatedAt().toString(),
            user.getLastRolloverDate() != null ? user.getLastRolloverDate().toString() : null,
            user.getUpdatedAt().toString()
        );
        return ResponseEntity.ok(response);
    }
}
