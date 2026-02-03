import api from './api';
import type { User, TodueExport, ImportFormat, ImportResponse } from '../types';

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
  async updateTimezone(timezone: string): Promise<User> {
    const response = await api.put<User>('/user/timezone', { timezone });
    return response.data;
  },

  /**
   * Update user's accent color
   */
  async updateAccentColor(accentColor: string | null): Promise<User> {
    const response = await api.put<User>('/user/accent-color', { accentColor });
    return response.data;
  },

  /**
   * Export all user data as JSON
   */
  async exportData(): Promise<TodueExport> {
    const response = await api.get<TodueExport>('/user/export');
    return response.data;
  },

  /**
   * Import data from external source
   */
  async importData(format: ImportFormat, data: unknown): Promise<ImportResponse> {
    const response = await api.post<ImportResponse>('/user/import', { format, data });
    return response.data;
  },
};
