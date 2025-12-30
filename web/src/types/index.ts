// User types
export interface User {
  id: number;
  email: string;
  timezone: string;
}

export interface AuthResponse {
  token: string;
  user: User;
}

// Todo types
export enum RecurrenceType {
  DAILY = 'DAILY',
  WEEKLY = 'WEEKLY',
  BIWEEKLY = 'BIWEEKLY',
  MONTHLY = 'MONTHLY',
  YEARLY = 'YEARLY',
}

export interface Todo {
  id: number | null;
  text: string;
  assignedDate: string; // ISO date string
  instanceDate: string; // ISO date string
  position: number;
  recurringTodoId: number | null;
  isCompleted: boolean;
  completedAt: string | null; // ISO datetime string
  isRolledOver: boolean;
  isVirtual: boolean;
}

export interface RecurringTodo {
  id: number;
  text: string;
  recurrenceType: RecurrenceType;
  startDate: string; // ISO date string
  endDate: string | null; // ISO date string
}

// WebSocket types
export enum WebSocketMessageType {
  TODOS_CHANGED = 'TODOS_CHANGED',      // Single date changed - refetch that date
  RECURRING_CHANGED = 'RECURRING_CHANGED', // Recurring pattern changed - refetch all visible dates
}

export interface WebSocketMessage<T = any> {
  type: WebSocketMessageType;
  data: T;
  timestamp: string; // ISO datetime string
}

// API Request/Response types
export interface LoginRequest {
  email: string;
  password: string;
}

export interface RegisterRequest {
  email: string;
  password: string;
  timezone?: string;
}

export interface CreateTodoRequest {
  text: string;
  assignedDate: string; // ISO date string
}

export interface UpdateTodoTextRequest {
  text: string;
}

export interface UpdateTodoPositionRequest {
  position: number;
}

export interface VirtualTodoRequest {
  recurringTodoId: number;
  instanceDate: string; // ISO date string
}

export interface ResetPasswordRequest {
  token: string;
  newPassword: string;
}

// Utility types
export type ViewMode = 1 | 3 | 5 | 7;
