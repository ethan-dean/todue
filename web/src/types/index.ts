// User types
export interface User {
  id: number;
  email: string;
  timezone: string;
  createdAt?: string;
  lastRolloverDate?: string | null;
  updatedAt?: string;
}

export interface AuthResponse {
  token: string;
  user: User;
}

export interface RegistrationResponse {
  message: string;
  email: string;
}

// Todo types
export const RecurrenceType = {
  DAILY: 'DAILY',
  WEEKLY: 'WEEKLY',
  BIWEEKLY: 'BIWEEKLY',
  MONTHLY: 'MONTHLY',
  YEARLY: 'YEARLY',
} as const;

export type RecurrenceType = typeof RecurrenceType[keyof typeof RecurrenceType];

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
export const WebSocketMessageType = {
  TODOS_CHANGED: 'TODOS_CHANGED',           // Single date changed - refetch that date
  RECURRING_CHANGED: 'RECURRING_CHANGED',   // Recurring pattern changed - refetch all visible dates
  LATER_LIST_CHANGED: 'LATER_LIST_CHANGED', // Later list changed - refetch that list
} as const;

export type WebSocketMessageType = typeof WebSocketMessageType[keyof typeof WebSocketMessageType];

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

export interface UpdateAssignedDateRequest {
  toDate: string; // ISO date string
}

export interface VirtualTodoRequest {
  recurringTodoId: number;
  instanceDate: string; // ISO date string
}

export interface ResetPasswordRequest {
  token: string;
  newPassword: string;
}

// Later Lists types
export interface LaterList {
  id: number;
  listName: string;
}

export interface LaterListTodo {
  id: number;
  text: string;
  isCompleted: boolean;
  completedAt: string | null; // ISO datetime string
  position: number;
}

export interface CreateLaterListRequest {
  listName: string;
}

export interface CreateLaterListTodoRequest {
  text: string;
  position?: number;
}

export interface UpdateLaterListNameRequest {
  listName: string;
}

export interface UpdateLaterListTodoTextRequest {
  text: string;
}

export interface UpdateLaterListTodoPositionRequest {
  position: number;
}

// Utility types
export type ViewMode = 1 | 3 | 5 | 7;
