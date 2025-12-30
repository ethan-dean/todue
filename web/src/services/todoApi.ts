import api from './api';
import type { Todo, CreateTodoRequest, UpdateTodoTextRequest, UpdateTodoPositionRequest, VirtualTodoRequest } from '../types';

export const todoApi = {
  /**
   * Get todos for a specific date
   */
  async getTodosForDate(date: string): Promise<Todo[]> {
    const response = await api.get<Todo[]>('/todos', {
      params: { date },
    });
    return response.data;
  },

  /**
   * Get todos for a date range
   */
  async getTodosForDateRange(startDate: string, endDate: string): Promise<Todo[]> {
    const response = await api.get<Todo[]>('/todos', {
      params: { startDate, endDate },
    });
    return response.data;
  },

  /**
   * Create a new todo
   */
  async createTodo(text: string, assignedDate: string): Promise<Todo> {
    const request: CreateTodoRequest = { text, assignedDate };
    const response = await api.post<Todo>('/todos', request);
    return response.data;
  },

  /**
   * Update todo text
   */
  async updateTodoText(id: number, text: string): Promise<Todo> {
    const request: UpdateTodoTextRequest = { text };
    const response = await api.put<Todo>(`/todos/${id}/text`, request);
    return response.data;
  },

  /**
   * Update todo position
   */
  async updateTodoPosition(id: number, position: number): Promise<Todo> {
    const request: UpdateTodoPositionRequest = { position };
    const response = await api.put<Todo>(`/todos/${id}/position`, request);
    return response.data;
  },

  /**
   * Mark todo as complete
   */
  async completeTodo(id: number): Promise<Todo> {
    const response = await api.post<Todo>(`/todos/${id}/complete`);
    return response.data;
  },

  /**
   * Delete a todo
   */
  async deleteTodo(id: number, deleteAllFuture?: boolean): Promise<{ message: string }> {
    const response = await api.delete<{ message: string }>(`/todos/${id}`, {
      params: deleteAllFuture ? { deleteAllFuture } : {},
    });
    return response.data;
  },

  // Virtual todo operations

  /**
   * Complete a virtual todo
   */
  async completeVirtualTodo(recurringTodoId: number, instanceDate: string): Promise<Todo> {
    const request: VirtualTodoRequest = { recurringTodoId, instanceDate };
    const response = await api.post<Todo>('/todos/virtual/complete', request);
    return response.data;
  },

  /**
   * Update virtual todo text
   */
  async updateVirtualTodoText(recurringTodoId: number, instanceDate: string, text: string): Promise<Todo> {
    const request: VirtualTodoRequest = { recurringTodoId, instanceDate };
    const response = await api.post<Todo>('/todos/virtual/update-text', request, {
      params: { text },
    });
    return response.data;
  },

  /**
   * Update virtual todo position
   */
  async updateVirtualTodoPosition(recurringTodoId: number, instanceDate: string, position: number): Promise<Todo> {
    const request: VirtualTodoRequest = { recurringTodoId, instanceDate };
    const response = await api.post<Todo>('/todos/virtual/update-position', request, {
      params: { position },
    });
    return response.data;
  },

  /**
   * Delete a virtual todo
   */
  async deleteVirtualTodo(recurringTodoId: number, instanceDate: string, deleteAllFuture?: boolean): Promise<{ message: string }> {
    const params: any = { recurringTodoId, instanceDate };
    if (deleteAllFuture) {
      params.deleteAllFuture = deleteAllFuture;
    }
    const response = await api.delete<{ message: string }>('/todos/virtual', { params });
    return response.data;
  },
};
