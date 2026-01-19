import api from './api';
import type {
  LaterList,
  LaterListTodo,
  CreateLaterListRequest,
  CreateLaterListTodoRequest,
  UpdateLaterListNameRequest,
  UpdateLaterListTodoTextRequest,
  UpdateLaterListTodoPositionRequest,
} from '../types';

export const laterListApi = {
  // ==================== List Operations ====================

  async getAllLists(): Promise<LaterList[]> {
    const response = await api.get<LaterList[]>('/later-lists');
    return response.data;
  },

  async createList(listName: string): Promise<LaterList> {
    const request: CreateLaterListRequest = { listName };
    const response = await api.post<LaterList>('/later-lists', request);
    return response.data;
  },

  async updateListName(listId: number, listName: string): Promise<LaterList> {
    const request: UpdateLaterListNameRequest = { listName };
    const response = await api.put<LaterList>(`/later-lists/${listId}/name`, request);
    return response.data;
  },

  async deleteList(listId: number): Promise<{ message: string }> {
    const response = await api.delete<{ message: string }>(`/later-lists/${listId}`);
    return response.data;
  },

  // ==================== Todo Operations ====================

  async getTodosForList(listId: number): Promise<LaterListTodo[]> {
    const response = await api.get<LaterListTodo[]>(`/later-lists/${listId}/todos`);
    return response.data;
  },

  async createTodo(listId: number, text: string, position?: number): Promise<LaterListTodo> {
    const request: CreateLaterListTodoRequest = { text, position };
    const response = await api.post<LaterListTodo>(`/later-lists/${listId}/todos`, request);
    return response.data;
  },

  async updateTodoText(listId: number, todoId: number, text: string): Promise<LaterListTodo> {
    const request: UpdateLaterListTodoTextRequest = { text };
    const response = await api.put<LaterListTodo>(`/later-lists/${listId}/todos/${todoId}/text`, request);
    return response.data;
  },

  async updateTodoPosition(listId: number, todoId: number, position: number): Promise<LaterListTodo> {
    const request: UpdateLaterListTodoPositionRequest = { position };
    const response = await api.put<LaterListTodo>(`/later-lists/${listId}/todos/${todoId}/position`, request);
    return response.data;
  },

  async completeTodo(listId: number, todoId: number): Promise<LaterListTodo> {
    const response = await api.post<LaterListTodo>(`/later-lists/${listId}/todos/${todoId}/complete`);
    return response.data;
  },

  async uncompleteTodo(listId: number, todoId: number): Promise<LaterListTodo> {
    const response = await api.post<LaterListTodo>(`/later-lists/${listId}/todos/${todoId}/uncomplete`);
    return response.data;
  },

  async deleteTodo(listId: number, todoId: number): Promise<{ message: string }> {
    const response = await api.delete<{ message: string }>(`/later-lists/${listId}/todos/${todoId}`);
    return response.data;
  },
};
