package com.ethan.todue.service;

import com.ethan.todue.dto.AuthResponse;
import com.ethan.todue.dto.UserResponse;
import com.ethan.todue.model.EmailVerification;
import com.ethan.todue.model.PasswordResetToken;
import com.ethan.todue.model.User;
import com.ethan.todue.repository.EmailVerificationRepository;
import com.ethan.todue.repository.PasswordResetTokenRepository;
import com.ethan.todue.repository.UserRepository;
import com.ethan.todue.security.JwtUtil;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

@Service
public class AuthService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordResetTokenRepository passwordResetTokenRepository;

    @Autowired
    private EmailVerificationRepository emailVerificationRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private EmailService emailService;

    @Transactional
    public AuthResponse register(String email, String password, String timezone) {
        if (userRepository.existsByEmail(email)) {
            throw new RuntimeException("Email already exists");
        }

        User user = new User();
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode(password));
        user.setTimezone(timezone != null ? timezone : "UTC");
        user.setEmailVerified(false);

        user = userRepository.save(user);

        // Generate verification token and send email
        String verificationToken = UUID.randomUUID().toString();
        Instant expiresAt = Instant.now().plusSeconds(86400); // 24 hours

        EmailVerification verification = new EmailVerification();
        verification.setUser(user);
        verification.setToken(verificationToken);
        verification.setExpiresAt(expiresAt);
        emailVerificationRepository.save(verification);

        // Send verification email
        emailService.sendVerificationEmail(email, verificationToken);

        // Still return JWT token, but user can't login until verified
        String token = jwtUtil.generateToken(email);
        UserResponse userResponse = new UserResponse(user.getId(), user.getEmail(), user.getTimezone());

        return new AuthResponse(token, userResponse);
    }

    @Transactional
    public AuthResponse login(String email, String password) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("Invalid email or password"));

        if (!passwordEncoder.matches(password, user.getPasswordHash())) {
            throw new RuntimeException("Invalid email or password");
        }

        // Strict email verification - user must verify email before logging in
        if (!user.getEmailVerified()) {
            throw new RuntimeException("Email not verified. Please check your inbox for verification email.");
        }

        // Note: lastRolloverDate is updated by RolloverService, not on login
        String token = jwtUtil.generateToken(email);
        UserResponse userResponse = new UserResponse(user.getId(), user.getEmail(), user.getTimezone());

        return new AuthResponse(token, userResponse);
    }

    @Transactional
    public String requestPasswordReset(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        passwordResetTokenRepository.deleteByUserId(user.getId());

        String token = UUID.randomUUID().toString();
        Instant expiresAt = Instant.now().plusSeconds(3600); // 1 hour

        PasswordResetToken resetToken = new PasswordResetToken();
        resetToken.setUser(user);
        resetToken.setToken(token);
        resetToken.setExpiresAt(expiresAt);

        passwordResetTokenRepository.save(resetToken);

        // Send password reset email
        emailService.sendPasswordResetEmail(email, token);

        return token;
    }

    @Transactional
    public void resetPassword(String token, String newPassword) {
        PasswordResetToken resetToken = passwordResetTokenRepository.findByToken(token)
                .orElseThrow(() -> new RuntimeException("Invalid or expired token"));

        if (resetToken.getExpiresAt().isBefore(Instant.now())) {
            throw new RuntimeException("Token has expired");
        }

        User user = resetToken.getUser();
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        userRepository.save(user);

        passwordResetTokenRepository.delete(resetToken);
    }

    @Transactional
    public void verifyEmail(String token) {
        EmailVerification verification = emailVerificationRepository.findByToken(token)
                .orElseThrow(() -> new RuntimeException("Invalid or expired verification token"));

        if (verification.getExpiresAt().isBefore(Instant.now())) {
            throw new RuntimeException("Verification token has expired");
        }

        User user = verification.getUser();
        user.setEmailVerified(true);
        userRepository.save(user);

        emailVerificationRepository.delete(verification);
    }
}
