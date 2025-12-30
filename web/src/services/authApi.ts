import api from './api';
import type { AuthResponse, LoginRequest, RegisterRequest, ResetPasswordRequest } from '../types';

export const authApi = {
  /**
   * Register a new user
   */
  async register(email: string, password: string, timezone?: string): Promise<AuthResponse> {
    const request: RegisterRequest = {
      email,
      password,
      timezone: timezone || Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
    };
    const response = await api.post<AuthResponse>('/auth/register', request);
    return response.data;
  },

  /**
   * Login with email and password
   */
  async login(email: string, password: string): Promise<AuthResponse> {
    const request: LoginRequest = { email, password };
    const response = await api.post<AuthResponse>('/auth/login', request);
    return response.data;
  },

  /**
   * Request a password reset token
   */
  async requestPasswordReset(email: string): Promise<{ message: string; token: string }> {
    const response = await api.post<{ message: string; token: string }>(
      '/auth/reset-password-request',
      { email }
    );
    return response.data;
  },

  /**
   * Reset password with token
   */
  async resetPassword(token: string, newPassword: string): Promise<{ message: string }> {
    const request: ResetPasswordRequest = { token, newPassword };
    const response = await api.post<{ message: string }>('/auth/reset-password', request);
    return response.data;
  },

  /**
   * Verify email address with token
   */
  async verifyEmail(token: string): Promise<{ message: string }> {
    const response = await api.get<{ message: string }>(`/auth/verify-email?token=${token}`);
    return response.data;
  },
};
