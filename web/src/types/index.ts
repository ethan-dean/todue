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
  ROUTINE_CHANGED: 'ROUTINE_CHANGED',       // Routine changed - refetch routine(s)
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

// Routines types
export interface Routine {
  id: number;
  name: string;
  stepCount: number;
}

export interface RoutineStep {
  id: number;
  text: string;
  notes: string | null;
  position: number;
}

export interface RoutineSchedule {
  id: number;
  dayOfWeek: number;  // 0=Sunday through 6=Saturday
  promptTime: string | null;  // HH:mm:ss format or null
}

export interface RoutineDetail {
  id: number;
  name: string;
  steps: RoutineStep[];
  schedules: RoutineSchedule[];
}

export interface RoutineStepCompletion {
  id: number;
  stepId: number;
  stepText: string;
  stepNotes: string | null;
  stepPosition: number;
  status: 'PENDING' | 'COMPLETED' | 'SKIPPED';
  completedAt: string | null;
  notes: string | null;
}

export interface RoutineCompletion {
  id: number;
  routineId: number;
  routineName: string;
  date: string;  // ISO date string
  startedAt: string;  // ISO datetime string
  completedAt: string | null;
  status: 'IN_PROGRESS' | 'COMPLETED' | 'ABANDONED';
  stepCompletions: RoutineStepCompletion[];
  totalSteps: number;
  completedSteps: number;
  skippedSteps: number;
}

export interface RoutineStepAnalytics {
  stepId: number;
  stepText: string;
  completedCount: number;
  skippedCount: number;
  completionRate: number;
}

export interface RoutineAnalytics {
  routineId: number;
  routineName: string;
  calendarData: Record<string, string>;  // date -> status
  currentStreak: number;
  longestStreak: number;
  completionRate: number;
  totalCompletions: number;
  totalAbandoned: number;
  stepAnalytics: RoutineStepAnalytics[];
}

export interface RoutineHistory {
  id: number;
  date: string;
  startedAt: string;
  completedAt: string | null;
  status: 'IN_PROGRESS' | 'COMPLETED' | 'ABANDONED';
  totalSteps: number;
  completedSteps: number;
  skippedSteps: number;
}

export interface PendingRoutinePrompt {
  routineId: number;
  routineName: string;
  stepCount: number;
  scheduledTime: string | null;  // HH:mm:ss format
}

export interface CreateRoutineRequest {
  name: string;
}

export interface UpdateRoutineNameRequest {
  name: string;
}

export interface CreateRoutineStepRequest {
  text: string;
  notes?: string;
  position?: number;
}

export interface UpdateRoutineStepTextRequest {
  text: string;
}

export interface UpdateRoutineStepNotesRequest {
  notes: string | null;
}

export interface UpdateRoutineStepPositionRequest {
  position: number;
}

export interface ScheduleEntry {
  dayOfWeek: number;
  promptTime: string | null;
}

export interface SetRoutineSchedulesRequest {
  schedules: ScheduleEntry[];
}

export interface CompleteRoutineStepRequest {
  action: 'complete' | 'skip';
  notes?: string;
}

// Utility types
export type ViewMode = 1 | 3 | 5 | 7;
