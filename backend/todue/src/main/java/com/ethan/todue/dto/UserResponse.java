package com.ethan.todue.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class UserResponse {
    private Long id;
    private String email;
    private String timezone;
    private String accentColor;
    private String createdAt;
    private String lastRolloverDate;
    private String updatedAt;
}
