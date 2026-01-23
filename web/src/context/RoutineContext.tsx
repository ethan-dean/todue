import React, { createContext, useContext, useState, useEffect, useCallback, useRef, type ReactNode } from 'react';
import type {
  Routine,
  RoutineDetail,
  RoutineCompletion,
  RoutineStepCompletion,
  RoutineAnalytics,
  RoutineHistory,
  PendingRoutinePrompt,
  ScheduleEntry,
  WebSocketMessage,
} from '../types';
import { WebSocketMessageType } from '../types';
import { routineApi } from '../services/routineApi';
import { websocketService } from '../services/websocketService';
import { handleApiError } from '../services/api';
import { useAuth } from './AuthContext';

interface RoutineContextType {
  // Data
  routines: Routine[];
  currentRoutineId: number | null;
  routineDetails: Map<number, RoutineDetail>;
  activeExecutions: Map<number, RoutineCompletion>;
  pendingPrompts: PendingRoutinePrompt[];
  analytics: Map<number, RoutineAnalytics>;
  history: Map<number, RoutineHistory[]>;
  isLoading: boolean;
  error: string | null;

  // Routine CRUD
  loadRoutines: () => Promise<void>;
  loadRoutineDetail: (routineId: number) => Promise<void>;
  createRoutine: (name: string) => Promise<Routine>;
  updateRoutineName: (routineId: number, newName: string) => Promise<void>;
  deleteRoutine: (routineId: number) => Promise<void>;

  // Step CRUD
  createStep: (routineId: number, text: string, notes?: string) => Promise<void>;
  updateStepText: (routineId: number, stepId: number, text: string) => Promise<void>;
  updateStepNotes: (routineId: number, stepId: number, notes: string | null) => Promise<void>;
  updateStepPosition: (routineId: number, stepId: number, position: number) => Promise<void>;
  deleteStep: (routineId: number, stepId: number) => Promise<void>;

  // Schedules
  setSchedules: (routineId: number, schedules: ScheduleEntry[]) => Promise<void>;

  // Prompts
  loadPendingPrompts: () => Promise<void>;
  dismissPrompt: (routineId: number) => Promise<void>;

  // Execution
  quickCompleteRoutine: (routineId: number, completedStepIds?: number[]) => Promise<void>;
  startRoutine: (routineId: number) => Promise<RoutineCompletion>;
  loadActiveExecution: (routineId: number) => Promise<void>;
  completeStep: (completionId: number, stepId: number, action: 'complete' | 'skip', notes?: string) => Promise<void>;
  finishExecution: (completionId: number) => Promise<void>;
  abandonExecution: (completionId: number) => Promise<void>;

  // Analytics
  loadAnalytics: (routineId: number, startDate: string, endDate: string) => Promise<void>;
  loadHistory: (routineId: number, startDate: string, endDate: string) => Promise<void>;

  // Utility
  setCurrentRoutineId: (routineId: number | null) => void;
  clearError: () => void;
}

const RoutineContext = createContext<RoutineContextType | undefined>(undefined);

interface RoutineProviderProps {
  children: ReactNode;
}

export const RoutineProvider: React.FC<RoutineProviderProps> = ({ children }) => {
  const { isAuthenticated } = useAuth();
  const [routines, setRoutines] = useState<Routine[]>([]);
  const [currentRoutineId, setCurrentRoutineId] = useState<number | null>(null);
  const [routineDetails, setRoutineDetails] = useState<Map<number, RoutineDetail>>(new Map());
  const [activeExecutions, setActiveExecutions] = useState<Map<number, RoutineCompletion>>(new Map());
  const [pendingPrompts, setPendingPrompts] = useState<PendingRoutinePrompt[]>([]);
  const [analytics, setAnalytics] = useState<Map<number, RoutineAnalytics>>(new Map());
  const [history, setHistory] = useState<Map<number, RoutineHistory[]>>(new Map());
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  const lastMutationTimeRef = useRef<number>(0);
  const currentRoutineIdRef = useRef(currentRoutineId);

  useEffect(() => {
    currentRoutineIdRef.current = currentRoutineId;
  }, [currentRoutineId]);

  // ==================== Routine CRUD ====================

  const loadRoutines = useCallback(async (silent: boolean = false): Promise<void> => {
    const fetchStartTime = Date.now();
    if (!silent) setIsLoading(true);
    setError(null);

    try {
      const fetchedRoutines = await routineApi.getAllRoutines();
      if (fetchStartTime < lastMutationTimeRef.current) return;
      setRoutines(fetchedRoutines);
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      console.error('Failed to load routines:', err);
    } finally {
      if (!silent) setIsLoading(false);
    }
  }, []);

  const loadRoutineDetail = useCallback(async (routineId: number, silent: boolean = false): Promise<void> => {
    const fetchStartTime = Date.now();
    if (!silent) setIsLoading(true);
    setError(null);

    try {
      const detail = await routineApi.getRoutineDetail(routineId);
      if (fetchStartTime < lastMutationTimeRef.current) return;
      setRoutineDetails((prev) => {
        const newMap = new Map(prev);
        newMap.set(routineId, detail);
        return newMap;
      });
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      console.error('Failed to load routine detail:', err);
    } finally {
      if (!silent) setIsLoading(false);
    }
  }, []);

  const createRoutine = async (name: string): Promise<Routine> => {
    lastMutationTimeRef.current = Date.now();
    setError(null);
    try {
      const newRoutine = await routineApi.createRoutine(name);
      setRoutines((prev) => [...prev, newRoutine].sort((a, b) => a.name.localeCompare(b.name)));
      return newRoutine;
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const updateRoutineName = async (routineId: number, newName: string): Promise<void> => {
    lastMutationTimeRef.current = Date.now();

    // Optimistic update
    setRoutines((prev) =>
      prev.map((r) => (r.id === routineId ? { ...r, name: newName } : r)).sort((a, b) => a.name.localeCompare(b.name))
    );
    setRoutineDetails((prev) => {
      const detail = prev.get(routineId);
      if (detail) {
        const newMap = new Map(prev);
        newMap.set(routineId, { ...detail, name: newName });
        return newMap;
      }
      return prev;
    });

    setError(null);
    try {
      await routineApi.updateRoutineName(routineId, newName);
    } catch (err) {
      await loadRoutines(true);
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const deleteRoutine = async (routineId: number): Promise<void> => {
    lastMutationTimeRef.current = Date.now();

    // Optimistic update
    setRoutines((prev) => prev.filter((r) => r.id !== routineId));
    setRoutineDetails((prev) => {
      const newMap = new Map(prev);
      newMap.delete(routineId);
      return newMap;
    });

    setError(null);
    try {
      await routineApi.deleteRoutine(routineId);
      if (currentRoutineId === routineId) {
        setCurrentRoutineId(null);
      }
    } catch (err) {
      await loadRoutines(true);
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  // ==================== Step CRUD ====================

  const createStep = async (routineId: number, text: string, notes?: string): Promise<void> => {
    lastMutationTimeRef.current = Date.now();
    setError(null);
    try {
      const newStep = await routineApi.createStep(routineId, text, notes);
      setRoutineDetails((prev) => {
        const detail = prev.get(routineId);
        if (detail) {
          const newMap = new Map(prev);
          newMap.set(routineId, {
            ...detail,
            steps: [...detail.steps, newStep].sort((a, b) => a.position - b.position),
          });
          return newMap;
        }
        return prev;
      });
      // Update step count in routines list
      setRoutines((prev) =>
        prev.map((r) => (r.id === routineId ? { ...r, stepCount: r.stepCount + 1 } : r))
      );
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const updateStepText = async (routineId: number, stepId: number, text: string): Promise<void> => {
    lastMutationTimeRef.current = Date.now();

    // Optimistic update
    setRoutineDetails((prev) => {
      const detail = prev.get(routineId);
      if (detail) {
        const newMap = new Map(prev);
        newMap.set(routineId, {
          ...detail,
          steps: detail.steps.map((s) => (s.id === stepId ? { ...s, text } : s)),
        });
        return newMap;
      }
      return prev;
    });

    setError(null);
    try {
      await routineApi.updateStepText(routineId, stepId, text);
    } catch (err) {
      await loadRoutineDetail(routineId, true);
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const updateStepNotes = async (routineId: number, stepId: number, notes: string | null): Promise<void> => {
    lastMutationTimeRef.current = Date.now();

    // Optimistic update
    setRoutineDetails((prev) => {
      const detail = prev.get(routineId);
      if (detail) {
        const newMap = new Map(prev);
        newMap.set(routineId, {
          ...detail,
          steps: detail.steps.map((s) => (s.id === stepId ? { ...s, notes } : s)),
        });
        return newMap;
      }
      return prev;
    });

    setError(null);
    try {
      await routineApi.updateStepNotes(routineId, stepId, notes);
    } catch (err) {
      await loadRoutineDetail(routineId, true);
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const updateStepPosition = async (routineId: number, stepId: number, newPosition: number): Promise<void> => {
    lastMutationTimeRef.current = Date.now();

    // Optimistic update
    setRoutineDetails((prev) => {
      const detail = prev.get(routineId);
      if (!detail) return prev;

      const steps = [...detail.steps].sort((a, b) => a.position - b.position);
      const oldIndex = steps.findIndex((s) => s.id === stepId);
      if (oldIndex === -1 || oldIndex === newPosition) return prev;

      const [movedStep] = steps.splice(oldIndex, 1);
      steps.splice(newPosition, 0, movedStep);

      const reorderedSteps = steps.map((step, index) => ({ ...step, position: index + 1 }));

      const newMap = new Map(prev);
      newMap.set(routineId, { ...detail, steps: reorderedSteps });
      return newMap;
    });

    setError(null);
    try {
      await routineApi.updateStepPosition(routineId, stepId, newPosition);
    } catch (err) {
      await loadRoutineDetail(routineId, true);
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const deleteStep = async (routineId: number, stepId: number): Promise<void> => {
    lastMutationTimeRef.current = Date.now();

    // Optimistic update
    setRoutineDetails((prev) => {
      const detail = prev.get(routineId);
      if (detail) {
        const newMap = new Map(prev);
        newMap.set(routineId, {
          ...detail,
          steps: detail.steps.filter((s) => s.id !== stepId),
        });
        return newMap;
      }
      return prev;
    });
    setRoutines((prev) =>
      prev.map((r) => (r.id === routineId ? { ...r, stepCount: Math.max(0, r.stepCount - 1) } : r))
    );

    setError(null);
    try {
      await routineApi.deleteStep(routineId, stepId);
    } catch (err) {
      await loadRoutineDetail(routineId, true);
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  // ==================== Schedules ====================

  const setSchedules = async (routineId: number, schedules: ScheduleEntry[]): Promise<void> => {
    lastMutationTimeRef.current = Date.now();
    setError(null);
    try {
      const newSchedules = await routineApi.setSchedules(routineId, schedules);
      setRoutineDetails((prev) => {
        const detail = prev.get(routineId);
        if (detail) {
          const newMap = new Map(prev);
          newMap.set(routineId, { ...detail, schedules: newSchedules });
          return newMap;
        }
        return prev;
      });
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  // ==================== Prompts ====================

  const loadPendingPrompts = useCallback(async (): Promise<void> => {
    const fetchStartTime = Date.now();
    try {
      const prompts = await routineApi.getPendingPrompts();
      // Skip if a mutation happened after this fetch started
      if (fetchStartTime < lastMutationTimeRef.current) return;
      setPendingPrompts(prompts);
    } catch (err) {
      console.error('Failed to load pending prompts:', err);
    }
  }, []);

  const dismissPrompt = async (routineId: number): Promise<void> => {
    setError(null);
    try {
      await routineApi.dismissPrompt(routineId);
      setPendingPrompts((prev) => prev.filter((p) => p.routineId !== routineId));
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  // ==================== Execution ====================

  const quickCompleteRoutine = async (routineId: number, completedStepIds?: number[]): Promise<void> => {
    lastMutationTimeRef.current = Date.now();
    setError(null);
    try {
      await routineApi.quickCompleteRoutine(routineId, completedStepIds);
      // Remove from pending prompts
      setPendingPrompts((prev) => prev.filter((p) => p.routineId !== routineId));
      // Remove any active execution for this routine
      setActiveExecutions((prev) => {
        const newMap = new Map(prev);
        newMap.delete(routineId);
        return newMap;
      });
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const startRoutine = async (routineId: number): Promise<RoutineCompletion> => {
    lastMutationTimeRef.current = Date.now();
    setError(null);
    try {
      const completion = await routineApi.startRoutine(routineId);
      setActiveExecutions((prev) => {
        const newMap = new Map(prev);
        newMap.set(routineId, completion);
        return newMap;
      });
      // Remove from pending prompts if present
      setPendingPrompts((prev) => prev.filter((p) => p.routineId !== routineId));
      return completion;
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const loadActiveExecution = useCallback(async (routineId: number): Promise<void> => {
    const fetchStartTime = Date.now();
    try {
      const execution = await routineApi.getActiveExecution(routineId);
      // Skip if a mutation happened after this fetch started
      if (fetchStartTime < lastMutationTimeRef.current) return;
      setActiveExecutions((prev) => {
        const newMap = new Map(prev);
        if (execution) {
          newMap.set(routineId, execution);
        } else {
          newMap.delete(routineId);
        }
        return newMap;
      });
    } catch (err) {
      console.error('Failed to load active execution:', err);
    }
  }, []);

  const completeStep = async (
    completionId: number,
    stepId: number,
    action: 'complete' | 'skip',
    notes?: string
  ): Promise<void> => {
    lastMutationTimeRef.current = Date.now();

    // Find the routineId from activeExecutions
    let routineId: number | null = null;
    activeExecutions.forEach((exec, rId) => {
      if (exec.id === completionId) {
        routineId = rId;
      }
    });

    // Optimistic update
    if (routineId !== null) {
      setActiveExecutions((prev) => {
        const execution = prev.get(routineId!);
        if (!execution) return prev;

        const newMap = new Map(prev);
        const updatedStepCompletions = execution.stepCompletions.map((sc) =>
          sc.stepId === stepId
            ? {
                ...sc,
                status: action === 'complete' ? 'COMPLETED' : 'SKIPPED',
                completedAt: new Date().toISOString(),
                notes: notes ?? sc.notes,
              }
            : sc
        ) as RoutineStepCompletion[];

        const completedCount = updatedStepCompletions.filter((sc) => sc.status === 'COMPLETED').length;
        const skippedCount = updatedStepCompletions.filter((sc) => sc.status === 'SKIPPED').length;

        newMap.set(routineId!, {
          ...execution,
          stepCompletions: updatedStepCompletions,
          completedSteps: completedCount,
          skippedSteps: skippedCount,
        });
        return newMap;
      });
    }

    setError(null);
    try {
      await routineApi.completeStep(completionId, stepId, action, notes);
    } catch (err) {
      if (routineId !== null) {
        await loadActiveExecution(routineId);
      }
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const finishExecution = async (completionId: number): Promise<void> => {
    lastMutationTimeRef.current = Date.now();

    // Find routineId
    let routineId: number | null = null;
    activeExecutions.forEach((exec, rId) => {
      if (exec.id === completionId) {
        routineId = rId;
      }
    });

    setError(null);
    try {
      await routineApi.finishExecution(completionId);
      if (routineId !== null) {
        setActiveExecutions((prev) => {
          const newMap = new Map(prev);
          newMap.delete(routineId!);
          return newMap;
        });
      }
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const abandonExecution = async (completionId: number): Promise<void> => {
    lastMutationTimeRef.current = Date.now();

    // Find routineId
    let routineId: number | null = null;
    activeExecutions.forEach((exec, rId) => {
      if (exec.id === completionId) {
        routineId = rId;
      }
    });

    setError(null);
    try {
      await routineApi.abandonExecution(completionId);
      if (routineId !== null) {
        setActiveExecutions((prev) => {
          const newMap = new Map(prev);
          newMap.delete(routineId!);
          return newMap;
        });
      }
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  // ==================== Analytics ====================

  const loadAnalytics = useCallback(
    async (routineId: number, startDate: string, endDate: string): Promise<void> => {
      const fetchStartTime = Date.now();
      setError(null);
      try {
        const data = await routineApi.getAnalytics(routineId, startDate, endDate);
        // Skip if a mutation happened after this fetch started
        if (fetchStartTime < lastMutationTimeRef.current) return;
        setAnalytics((prev) => {
          const newMap = new Map(prev);
          newMap.set(routineId, data);
          return newMap;
        });
      } catch (err) {
        const errorMessage = handleApiError(err);
        setError(errorMessage);
        console.error('Failed to load analytics:', err);
      }
    },
    []
  );

  const loadHistory = useCallback(
    async (routineId: number, startDate: string, endDate: string): Promise<void> => {
      const fetchStartTime = Date.now();
      setError(null);
      try {
        const data = await routineApi.getHistory(routineId, startDate, endDate);
        // Skip if a mutation happened after this fetch started
        if (fetchStartTime < lastMutationTimeRef.current) return;
        setHistory((prev) => {
          const newMap = new Map(prev);
          newMap.set(routineId, data);
          return newMap;
        });
      } catch (err) {
        const errorMessage = handleApiError(err);
        setError(errorMessage);
        console.error('Failed to load history:', err);
      }
    },
    []
  );

  // ==================== Utility ====================

  const clearError = (): void => {
    setError(null);
  };

  // ==================== WebSocket Handler ====================

  const handleWebSocketMessage = useCallback(
    (message: WebSocketMessage): void => {
      console.log('RoutineContext WebSocket message:', message.type, message.data);

      const { routineId, action } = message.data as { routineId?: number; action: string };
      const messageTime = Date.now();

      setTimeout(() => {
        // Skip if we recently made a mutation (this is our own change echoing back)
        if (messageTime < lastMutationTimeRef.current + 500) {
          return;
        }

        switch (action) {
          case 'ROUTINE_CREATED':
          case 'ROUTINE_UPDATED':
          case 'ROUTINE_DELETED':
            loadRoutines(true);
            if (routineId && currentRoutineIdRef.current === routineId) {
              loadRoutineDetail(routineId, true);
            }
            break;
          case 'EXECUTION_STARTED':
          case 'EXECUTION_COMPLETED':
          case 'EXECUTION_ABANDONED':
          case 'STEP_COMPLETED':
            if (routineId) {
              loadActiveExecution(routineId);
            }
            break;
        }
      }, 300);
    },
    [loadRoutines, loadRoutineDetail, loadActiveExecution]
  );

  // ==================== Effects ====================

  // Load routines when authenticated
  useEffect(() => {
    if (isAuthenticated) {
      loadRoutines();
      loadPendingPrompts();
    }
  }, [isAuthenticated, loadRoutines, loadPendingPrompts]);

  // Load routine detail when currentRoutineId changes
  useEffect(() => {
    if (isAuthenticated && currentRoutineId !== null && !routineDetails.has(currentRoutineId)) {
      loadRoutineDetail(currentRoutineId);
    }
  }, [isAuthenticated, currentRoutineId, routineDetails, loadRoutineDetail]);

  // Subscribe to WebSocket updates
  useEffect(() => {
    if (!isAuthenticated) return;

    let unsubscribe: (() => void) | null = null;

    websocketService.onConnectionEstablished(() => {
      unsubscribe = websocketService.subscribe([WebSocketMessageType.ROUTINE_CHANGED], handleWebSocketMessage);
    });

    return () => {
      if (unsubscribe) {
        unsubscribe();
      }
    };
  }, [isAuthenticated, handleWebSocketMessage]);

  const value: RoutineContextType = {
    routines,
    currentRoutineId,
    routineDetails,
    activeExecutions,
    pendingPrompts,
    analytics,
    history,
    isLoading,
    error,
    loadRoutines,
    loadRoutineDetail,
    createRoutine,
    updateRoutineName,
    deleteRoutine,
    createStep,
    updateStepText,
    updateStepNotes,
    updateStepPosition,
    deleteStep,
    setSchedules,
    loadPendingPrompts,
    dismissPrompt,
    quickCompleteRoutine,
    startRoutine,
    loadActiveExecution,
    completeStep,
    finishExecution,
    abandonExecution,
    loadAnalytics,
    loadHistory,
    setCurrentRoutineId,
    clearError,
  };

  return <RoutineContext.Provider value={value}>{children}</RoutineContext.Provider>;
};

export const useRoutines = (): RoutineContextType => {
  const context = useContext(RoutineContext);
  if (context === undefined) {
    throw new Error('useRoutines must be used within a RoutineProvider');
  }
  return context;
};
