package com.ethan.todue.util;

import java.util.regex.Pattern;

public class PasswordValidator {

    // At least 8 characters
    private static final int MIN_LENGTH = 8;

    // Regex patterns for password requirements
    private static final Pattern UPPERCASE_PATTERN = Pattern.compile("[A-Z]");
    private static final Pattern LOWERCASE_PATTERN = Pattern.compile("[a-z]");
    private static final Pattern DIGIT_PATTERN = Pattern.compile("[0-9]");
    private static final Pattern SPECIAL_CHAR_PATTERN = Pattern.compile("[!@#$%^&*()_+\\-=\\[\\]{};':\"\\\\|,.<>/?]");

    /**
     * Validates password against all requirements
     * @param password the password to validate
     * @throws RuntimeException if password doesn't meet requirements
     */
    public static void validatePassword(String password) {
        if (password == null || password.isEmpty()) {
            throw new RuntimeException("Password is required");
        }

        if (password.length() < MIN_LENGTH) {
            throw new RuntimeException("Password must be at least " + MIN_LENGTH + " characters long");
        }

        if (!UPPERCASE_PATTERN.matcher(password).find()) {
            throw new RuntimeException("Password must contain at least one uppercase letter");
        }

        if (!DIGIT_PATTERN.matcher(password).find()) {
            throw new RuntimeException("Password must contain at least one number");
        }

        if (!SPECIAL_CHAR_PATTERN.matcher(password).find()) {
            throw new RuntimeException("Password must contain at least one special character");
        }
    }

    /**
     * Checks if password meets all requirements (returns boolean instead of throwing)
     * @param password the password to check
     * @return true if password meets all requirements, false otherwise
     */
    public static boolean isValidPassword(String password) {
        try {
            validatePassword(password);
            return true;
        } catch (RuntimeException e) {
            return false;
        }
    }
}
