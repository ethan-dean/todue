import api from './api';
import { User } from '../types';

export const userApi = {
  /**
   * Get current authenticated user
   */
  async getCurrentUser(): Promise<User> {
    const response = await api.get<User>('/user/me');
    return response.data;
  },

  /**
   * Get current date in user's timezone
   */
  async getCurrentDate(): Promise<string> {
    const response = await api.get<{ currentDate: string }>('/user/current-date');
    return response.data.currentDate;
  },

  /**
   * Update user's timezone
   */
  async updateTimezone(timezone: string): Promise<{ message: string }> {
    const response = await api.put<{ message: string }>('/user/timezone', { timezone });
    return response.data;
  },
};
