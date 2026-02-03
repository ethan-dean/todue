package com.ethan.todue.controller;

import com.ethan.todue.dto.UserResponse;
import com.ethan.todue.dto.export.TodueExportDto;
import com.ethan.todue.dto.importdata.ImportRequest;
import com.ethan.todue.dto.importdata.ImportResponse;
import com.ethan.todue.model.User;
import com.ethan.todue.service.ExportService;
import com.ethan.todue.service.ImportService;
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

    @Autowired
    private ExportService exportService;

    @Autowired
    private ImportService importService;

    @GetMapping("/me")
    public ResponseEntity<UserResponse> getCurrentUser() {
        User user = userService.getCurrentUser();
        UserResponse response = new UserResponse(
            user.getId(),
            user.getEmail(),
            user.getTimezone(),
            user.getAccentColor(),
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
            user.getAccentColor(),
            user.getCreatedAt().toString(),
            user.getLastRolloverDate() != null ? user.getLastRolloverDate().toString() : null,
            user.getUpdatedAt().toString()
        );
        return ResponseEntity.ok(response);
    }

    @PutMapping("/accent-color")
    public ResponseEntity<UserResponse> updateAccentColor(@RequestBody Map<String, String> request) {
        String accentColor = request.get("accentColor");
        User user = userService.updateAccentColor(accentColor);
        UserResponse response = new UserResponse(
            user.getId(),
            user.getEmail(),
            user.getTimezone(),
            user.getAccentColor(),
            user.getCreatedAt().toString(),
            user.getLastRolloverDate() != null ? user.getLastRolloverDate().toString() : null,
            user.getUpdatedAt().toString()
        );
        return ResponseEntity.ok(response);
    }

    @GetMapping("/timezones")
    public ResponseEntity<java.util.List<String>> getTimezones() {
        return ResponseEntity.ok(userService.getAvailableTimezones());
    }

    @GetMapping("/export")
    public ResponseEntity<TodueExportDto> exportData() {
        TodueExportDto exportData = exportService.exportUserData();
        return ResponseEntity.ok(exportData);
    }

    @PostMapping("/import")
    public ResponseEntity<ImportResponse> importData(@RequestBody ImportRequest request) {
        ImportResponse response = importService.importData(request);
        return ResponseEntity.ok(response);
    }
}
