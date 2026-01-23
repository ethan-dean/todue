import api from './api';
import type {
  Routine,
  RoutineDetail,
  RoutineStep,
  RoutineSchedule,
  RoutineCompletion,
  RoutineStepCompletion,
  RoutineAnalytics,
  RoutineHistory,
  PendingRoutinePrompt,
  CreateRoutineRequest,
  UpdateRoutineNameRequest,
  CreateRoutineStepRequest,
  UpdateRoutineStepTextRequest,
  UpdateRoutineStepNotesRequest,
  UpdateRoutineStepPositionRequest,
  SetRoutineSchedulesRequest,
  CompleteRoutineStepRequest,
} from '../types';

export const routineApi = {
  // ==================== Routine CRUD ====================

  async getAllRoutines(): Promise<Routine[]> {
    const response = await api.get<Routine[]>('/routines');
    return response.data;
  },

  async getRoutineDetail(routineId: number): Promise<RoutineDetail> {
    const response = await api.get<RoutineDetail>(`/routines/${routineId}`);
    return response.data;
  },

  async createRoutine(name: string): Promise<Routine> {
    const request: CreateRoutineRequest = { name };
    const response = await api.post<Routine>('/routines', request);
    return response.data;
  },

  async updateRoutineName(routineId: number, name: string): Promise<Routine> {
    const request: UpdateRoutineNameRequest = { name };
    const response = await api.put<Routine>(`/routines/${routineId}/name`, request);
    return response.data;
  },

  async deleteRoutine(routineId: number): Promise<{ message: string }> {
    const response = await api.delete<{ message: string }>(`/routines/${routineId}`);
    return response.data;
  },

  // ==================== Step CRUD ====================

  async createStep(routineId: number, text: string, notes?: string, position?: number): Promise<RoutineStep> {
    const request: CreateRoutineStepRequest = { text, notes, position };
    const response = await api.post<RoutineStep>(`/routines/${routineId}/steps`, request);
    return response.data;
  },

  async updateStepText(routineId: number, stepId: number, text: string): Promise<RoutineStep> {
    const request: UpdateRoutineStepTextRequest = { text };
    const response = await api.put<RoutineStep>(`/routines/${routineId}/steps/${stepId}/text`, request);
    return response.data;
  },

  async updateStepNotes(routineId: number, stepId: number, notes: string | null): Promise<RoutineStep> {
    const request: UpdateRoutineStepNotesRequest = { notes };
    const response = await api.put<RoutineStep>(`/routines/${routineId}/steps/${stepId}/notes`, request);
    return response.data;
  },

  async updateStepPosition(routineId: number, stepId: number, position: number): Promise<RoutineStep> {
    const request: UpdateRoutineStepPositionRequest = { position };
    const response = await api.put<RoutineStep>(`/routines/${routineId}/steps/${stepId}/position`, request);
    return response.data;
  },

  async deleteStep(routineId: number, stepId: number): Promise<{ message: string }> {
    const response = await api.delete<{ message: string }>(`/routines/${routineId}/steps/${stepId}`);
    return response.data;
  },

  // ==================== Schedules ====================

  async setSchedules(routineId: number, schedules: SetRoutineSchedulesRequest['schedules']): Promise<RoutineSchedule[]> {
    const request: SetRoutineSchedulesRequest = { schedules };
    const response = await api.put<RoutineSchedule[]>(`/routines/${routineId}/schedules`, request);
    return response.data;
  },

  // ==================== Prompts ====================

  async getPendingPrompts(): Promise<PendingRoutinePrompt[]> {
    const response = await api.get<PendingRoutinePrompt[]>('/routines/prompts/pending');
    return response.data;
  },

  async dismissPrompt(routineId: number): Promise<{ message: string }> {
    const response = await api.post<{ message: string }>(`/routines/prompts/${routineId}/dismiss`);
    return response.data;
  },

  // ==================== Execution ====================

  async quickCompleteRoutine(routineId: number, completedStepIds?: number[]): Promise<RoutineCompletion> {
    const body = completedStepIds ? { completedStepIds } : null;
    const response = await api.post<RoutineCompletion>(`/routines/${routineId}/quick-complete`, body);
    return response.data;
  },

  async startRoutine(routineId: number): Promise<RoutineCompletion> {
    const response = await api.post<RoutineCompletion>(`/routines/${routineId}/start`);
    return response.data;
  },

  async getActiveExecution(routineId: number): Promise<RoutineCompletion | null> {
    const response = await api.get<RoutineCompletion>(`/routines/${routineId}/active`);
    // Returns 204 No Content if no active execution
    return response.status === 204 ? null : response.data;
  },

  async completeStep(
    completionId: number,
    stepId: number,
    action: 'complete' | 'skip',
    notes?: string
  ): Promise<RoutineStepCompletion> {
    const request: CompleteRoutineStepRequest = { action, notes };
    const response = await api.post<RoutineStepCompletion>(
      `/routines/executions/${completionId}/steps/${stepId}`,
      request
    );
    return response.data;
  },

  async finishExecution(completionId: number): Promise<RoutineCompletion> {
    const response = await api.post<RoutineCompletion>(`/routines/executions/${completionId}/finish`);
    return response.data;
  },

  async abandonExecution(completionId: number): Promise<RoutineCompletion> {
    const response = await api.post<RoutineCompletion>(`/routines/executions/${completionId}/abandon`);
    return response.data;
  },

  // ==================== Analytics ====================

  async getAnalytics(routineId: number, startDate: string, endDate: string): Promise<RoutineAnalytics> {
    const response = await api.get<RoutineAnalytics>(
      `/routines/${routineId}/analytics?startDate=${startDate}&endDate=${endDate}`
    );
    return response.data;
  },

  async getHistory(routineId: number, startDate: string, endDate: string): Promise<RoutineHistory[]> {
    const response = await api.get<RoutineHistory[]>(
      `/routines/${routineId}/history?startDate=${startDate}&endDate=${endDate}`
    );
    return response.data;
  },
};
