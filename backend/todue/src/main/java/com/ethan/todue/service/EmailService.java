package com.ethan.todue.service;

import com.resend.Resend;
import com.resend.core.exception.ResendException;
import com.resend.services.emails.model.CreateEmailOptions;
import com.resend.services.emails.model.CreateEmailResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class EmailService {

    private final Resend resend;
    private final String fromEmail;
    private final String appUrl;

    public EmailService(
            @Value("${resend.api.key}") String apiKey,
            @Value("${email.from}") String fromEmail,
            @Value("${app.url}") String appUrl
    ) {
        this.resend = new Resend(apiKey);
        this.fromEmail = fromEmail;
        this.appUrl = appUrl;
    }

    /**
     * Send email verification email to new user
     */
    public void sendVerificationEmail(String toEmail, String token) {
        String verificationUrl = appUrl + "/verify-email?token=" + token;

        String htmlContent = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
            </head>
            <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
                <div style="background-color: #f8f9fa; border-radius: 8px; padding: 30px; margin: 20px 0;">
                    <h1 style="color: #2563eb; margin-top: 0;">Welcome to ToDue!</h1>
                    <p style="font-size: 16px; margin: 20px 0;">Thanks for signing up. Please verify your email address to get started.</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="%s" style="background-color: #2563eb; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: 600;">Verify Email Address</a>
                    </div>
                    <p style="font-size: 14px; color: #666; margin-top: 30px;">Or copy and paste this link into your browser:</p>
                    <p style="font-size: 12px; color: #666; word-break: break-all; background-color: #fff; padding: 10px; border-radius: 4px;">%s</p>
                    <p style="font-size: 12px; color: #999; margin-top: 30px;">This link will expire in 24 hours.</p>
                </div>
            </body>
            </html>
            """.formatted(verificationUrl, verificationUrl);

        sendEmail(
                toEmail,
                "Verify your ToDue email address",
                htmlContent
        );
    }

    /**
     * Send password reset email
     */
    public void sendPasswordResetEmail(String toEmail, String token) {
        String resetUrl = appUrl + "/reset-password?token=" + token;

        String htmlContent = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
            </head>
            <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
                <div style="background-color: #f8f9fa; border-radius: 8px; padding: 30px; margin: 20px 0;">
                    <h1 style="color: #dc2626; margin-top: 0;">Reset Your Password</h1>
                    <p style="font-size: 16px; margin: 20px 0;">We received a request to reset your password. Click the button below to create a new password.</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="%s" style="background-color: #dc2626; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: 600;">Reset Password</a>
                    </div>
                    <p style="font-size: 14px; color: #666; margin-top: 30px;">Or copy and paste this link into your browser:</p>
                    <p style="font-size: 12px; color: #666; word-break: break-all; background-color: #fff; padding: 10px; border-radius: 4px;">%s</p>
                    <p style="font-size: 12px; color: #999; margin-top: 30px;">This link will expire in 1 hour.</p>
                    <p style="font-size: 12px; color: #999;">If you didn't request this, you can safely ignore this email.</p>
                </div>
            </body>
            </html>
            """.formatted(resetUrl, resetUrl);

        sendEmail(
                toEmail,
                "Reset your ToDue password",
                htmlContent
        );
    }

    /**
     * Internal method to send email via Resend
     */
    private void sendEmail(String to, String subject, String htmlContent) {
        try {
            CreateEmailOptions params = CreateEmailOptions.builder()
                    .from(fromEmail)
                    .to(to)
                    .subject(subject)
                    .html(htmlContent)
                    .build();

            CreateEmailResponse response = resend.emails().send(params);
            System.out.println("Email sent successfully. ID: " + response.getId());

        } catch (ResendException e) {
            System.err.println("Failed to send email to " + to + ": " + e.getMessage());
            throw new RuntimeException("Failed to send email: " + e.getMessage(), e);
        }
    }
}
