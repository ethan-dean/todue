import React, { createContext, useContext, useState, useEffect, useCallback, useRef, type ReactNode } from 'react';
import type { Todo, WebSocketMessage } from '../types';
import { WebSocketMessageType } from '../types';
import { todoApi } from '../services/todoApi';
import { websocketService } from '../services/websocketService';
import { handleApiError } from '../services/api';
import { useAuth } from './AuthContext';
import { formatDateForAPI, getCurrentDate, getDateRange } from '../utils/dateUtils';

type ViewMode = 1 | 3 | 5 | 7;

interface TodoContextType {
  todos: Map<string, Todo[]>;
  selectedDate: Date;
  viewMode: ViewMode;
  isLoading: boolean;
  error: string | null;
  loadTodosForDate: (date: Date) => Promise<void>;
  loadTodosForDateRange: (startDate: Date, endDate: Date) => Promise<void>;
  createTodo: (text: string, date: Date) => Promise<void>;
  updateTodoText: (id: number, text: string, isVirtual: boolean, recurringTodoId: number | null, instanceDate: string) => Promise<void>;
  updateTodoPosition: (id: number, position: number, isVirtual: boolean, recurringTodoId: number | null, instanceDate: string) => Promise<void>;
  completeTodo: (id: number, isVirtual: boolean, recurringTodoId: number | null, instanceDate: string) => Promise<void>;
  deleteTodo: (id: number, isVirtual: boolean, recurringTodoId: number | null, instanceDate: string, deleteAllFuture?: boolean) => Promise<void>;
  setViewMode: (mode: ViewMode) => void;
  changeDate: (newDate: Date) => void;
  clearError: () => void;
}

const TodoContext = createContext<TodoContextType | undefined>(undefined);

interface TodoProviderProps {
  children: ReactNode;
}

export const TodoProvider: React.FC<TodoProviderProps> = ({ children }) => {
  const { isAuthenticated } = useAuth();
  const [todos, setTodos] = useState<Map<string, Todo[]>>(new Map());
  const [selectedDate, setSelectedDate] = useState<Date>(getCurrentDate());
  const [viewMode, setViewMode] = useState<ViewMode>(1);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  // Refs to track current values for WebSocket callback
  const selectedDateRef = useRef(selectedDate);
  const viewModeRef = useRef(viewMode);
  const recentMutationsRef = useRef<Set<string>>(new Set());

  // Keep refs in sync with state
  useEffect(() => {
    selectedDateRef.current = selectedDate;
  }, [selectedDate]);

  useEffect(() => {
    viewModeRef.current = viewMode;
  }, [viewMode]);

  // Helper to record mutations we just made (to avoid refetching our own changes)
  const MUTATION_TRACKING_DURATION_MS = 2000;

  const recordMutation = useCallback((date: string) => {
    const key = date;
    recentMutationsRef.current.add(key);

    // Auto-cleanup after duration expires
    setTimeout(() => {
      recentMutationsRef.current.delete(key);
    }, MUTATION_TRACKING_DURATION_MS);
  }, []);

  // Helper to check if a mutation is one we recently made
  const isRecentMutation = useCallback((date: string): boolean => {
    return recentMutationsRef.current.has(date);
  }, []);

  // Helper to parse ISO date string (YYYY-MM-DD) to Date object in local timezone
  // Avoids timezone shift issues when using new Date(string) which interprets as UTC
  const parseDateString = useCallback((dateStr: string): Date => {
    const [year, month, day] = dateStr.split('-').map(Number);
    return new Date(year, month - 1, day);
  }, []);

  const loadTodosForDate = useCallback(async (date: Date, silent: boolean = false): Promise<void> => {
    // Only show loading state if not silent (e.g., initial load, manual refresh)
    // Silent refetches (from WebSocket) don't clear the UI
    if (!silent) {
      setIsLoading(true);
    }
    setError(null);
    try {
      const dateStr = formatDateForAPI(date);
      const fetchedTodos = await todoApi.getTodosForDate(dateStr);

      setTodos((prevTodos) => {
        const newTodos = new Map(prevTodos);
        newTodos.set(dateStr, fetchedTodos);
        return newTodos;
      });
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      console.error('Failed to load todos:', err);
    } finally {
      if (!silent) {
        setIsLoading(false);
      }
    }
  }, []);

  const loadTodosForDateRange = useCallback(async (startDate: Date, endDate: Date): Promise<void> => {
    setIsLoading(true);
    setError(null);
    try {
      const startDateStr = formatDateForAPI(startDate);
      const endDateStr = formatDateForAPI(endDate);
      const fetchedTodos = await todoApi.getTodosForDateRange(startDateStr, endDateStr);

      // Group todos by assigned_date
      const todosByDate = new Map<string, Todo[]>();
      fetchedTodos.forEach((todo) => {
        const dateKey = todo.assignedDate;
        if (!todosByDate.has(dateKey)) {
          todosByDate.set(dateKey, []);
        }
        todosByDate.get(dateKey)!.push(todo);
      });

      setTodos(todosByDate);
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      console.error('Failed to load todos:', err);
    } finally {
      setIsLoading(false);
    }
  }, []);

  const loadTodosForCurrentView = useCallback(async (): Promise<void> => {
    if (viewMode === 1) {
      await loadTodosForDate(selectedDate);
    } else {
      const dates = getDateRange(selectedDate, viewMode);
      await loadTodosForDateRange(dates[0], dates[dates.length - 1]);
    }
  }, [viewMode, selectedDate, loadTodosForDate, loadTodosForDateRange]);

  const createTodo = async (text: string, date: Date): Promise<void> => {
    setError(null);
    try {
      const dateStr = formatDateForAPI(date);

      // Record mutation BEFORE API call to prevent race condition with WebSocket
      recordMutation(dateStr);

      const newTodo = await todoApi.createTodo(text, dateStr);

      // Add to local state
      addTodoToState(newTodo);
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const updateTodoText = async (
    id: number,
    text: string,
    isVirtual: boolean,
    recurringTodoId: number | null,
    instanceDate: string
  ): Promise<void> => {
    setError(null);
    try {
      // Record mutation BEFORE API call (use instanceDate for date tracking)
      recordMutation(instanceDate);

      let updatedTodo: Todo;
      if (isVirtual && recurringTodoId) {
        updatedTodo = await todoApi.updateVirtualTodoText(recurringTodoId, instanceDate, text);
      } else {
        updatedTodo = await todoApi.updateTodoText(id, text);
      }

      updateTodoInState(updatedTodo);
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const updateTodoPosition = async (
    id: number,
    position: number,
    isVirtual: boolean,
    recurringTodoId: number | null,
    instanceDate: string
  ): Promise<void> => {
    setError(null);
    try {
      // Record mutation BEFORE API call (use instanceDate for date tracking)
      recordMutation(instanceDate);

      let updatedTodo: Todo;
      if (isVirtual && recurringTodoId) {
        updatedTodo = await todoApi.updateVirtualTodoPosition(recurringTodoId, instanceDate, position);
      } else {
        updatedTodo = await todoApi.updateTodoPosition(id, position);
      }

      updateTodoInState(updatedTodo);
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const completeTodo = async (
    id: number,
    isVirtual: boolean,
    recurringTodoId: number | null,
    instanceDate: string
  ): Promise<void> => {
    setError(null);

    // Record mutation immediately to catch fast WebSocket messages
    recordMutation(instanceDate);

    try {
      let completedTodo: Todo;
      if (isVirtual && recurringTodoId) {
        completedTodo = await todoApi.completeVirtualTodo(recurringTodoId, instanceDate);
      } else {
        completedTodo = await todoApi.completeTodo(id);
      }

      updateTodoInState(completedTodo);
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const deleteTodo = async (
    id: number,
    isVirtual: boolean,
    recurringTodoId: number | null,
    instanceDate: string,
    deleteAllFuture?: boolean
  ): Promise<void> => {
    setError(null);
    try {
      if (isVirtual && recurringTodoId) {
        // Record mutation BEFORE API call to prevent race condition
        recordMutation(instanceDate);

        await todoApi.deleteVirtualTodo(recurringTodoId, instanceDate, deleteAllFuture);

        // Remove virtual todo from state
        removeTodoFromState(id, instanceDate);
      } else {
        // Find the todo to get its assigned date BEFORE deletion
        let todoDateStr: string | null = null;
        todos.forEach((todoList, dateKey) => {
          const foundTodo = todoList.find(t => t.id === id);
          if (foundTodo) {
            todoDateStr = dateKey;
          }
        });

        if (todoDateStr) {
          // Record mutation BEFORE API call to prevent race condition
          recordMutation(todoDateStr);
        }

        await todoApi.deleteTodo(id, deleteAllFuture);

        if (todoDateStr) {
          removeTodoFromState(id, todoDateStr);
        }
      }
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const changeDate = (newDate: Date): void => {
    setSelectedDate(newDate);
  };

  const clearError = (): void => {
    setError(null);
  };

  // Helper functions for state management

  const addTodoToState = (todo: Todo): void => {
    setTodos((prevTodos) => {
      const newTodos = new Map(prevTodos);
      const dateKey = todo.assignedDate;
      const dateList = newTodos.get(dateKey) || [];
      newTodos.set(dateKey, [...dateList, todo]);
      return newTodos;
    });
  };

  const updateTodoInState = (todo: Todo): void => {
    setTodos((prevTodos) => {
      const newTodos = new Map(prevTodos);
      const dateKey = todo.assignedDate;
      const dateList = newTodos.get(dateKey) || [];
      const updatedList = dateList.map((t) =>
        (t.id === todo.id || (t.isVirtual && todo.isVirtual && t.instanceDate === todo.instanceDate && t.recurringTodoId === todo.recurringTodoId))
          ? todo
          : t
      );
      newTodos.set(dateKey, updatedList);
      return newTodos;
    });
  };

  const removeTodoFromState = (todoId: number, dateStr: string): void => {
    setTodos((prevTodos) => {
      const newTodos = new Map(prevTodos);
      const dateList = newTodos.get(dateStr) || [];
      const filteredList = dateList.filter((t) => t.id !== todoId);
      if (filteredList.length === 0) {
        newTodos.delete(dateStr);
      } else {
        newTodos.set(dateStr, filteredList);
      }
      return newTodos;
    });
  };

  // WebSocket message handler
  const handleWebSocketMessage = useCallback((message: WebSocketMessage): void => {
    console.log('WebSocket message received:', message);

    switch (message.type) {
      case WebSocketMessageType.TODOS_CHANGED:
        // Single date changed - refetch that specific date
        if (message.data && typeof message.data === 'object') {
          const { date } = message.data as { date: string };

          if (date) {
            // Check if this is our own recent mutation
            if (isRecentMutation(date)) {
              console.log('Ignoring own mutation for date:', date);
              return; // Skip refetch for our own changes
            }

            // Only refetch if this date is currently visible
            // Use refs to get current values instead of closure values
            if (viewModeRef.current === 1) {
              // Single day view - only refetch if it's the selected date
              if (formatDateForAPI(selectedDateRef.current) === date) {
                // Silent refetch - don't show loading spinner for external changes
                loadTodosForDate(parseDateString(date), true);
              }
            } else {
              // Multi-day view - refetch if the date is in visible range
              const dates = getDateRange(selectedDateRef.current, viewModeRef.current);
              const isVisible = dates.some(d => formatDateForAPI(d) === date);
              if (isVisible) {
                // Silent refetch - don't show loading spinner for external changes
                loadTodosForDate(parseDateString(date), true);
              }
            }
          }
        }
        break;

      case WebSocketMessageType.RECURRING_CHANGED:
        // Recurring pattern changed - refetch all currently visible dates
        loadTodosForCurrentView();
        break;

      default:
        console.warn('Unknown WebSocket message type:', message.type);
    }
  }, [isRecentMutation, parseDateString, loadTodosForDate, loadTodosForCurrentView]);

  // Load todos when date or view mode changes
  useEffect(() => {
    if (isAuthenticated) {
      loadTodosForCurrentView();
    }
  }, [selectedDate, viewMode, isAuthenticated, loadTodosForCurrentView]);

  // Subscribe to WebSocket updates when connection is established
  useEffect(() => {
    if (!isAuthenticated) return;

    let unsubscribe: (() => void) | null = null;

    websocketService.onConnectionEstablished(() => {
      unsubscribe = websocketService.subscribe(handleWebSocketMessage);
    });

    // Cleanup: unsubscribe when component unmounts or auth changes
    return () => {
      if (unsubscribe) {
        unsubscribe();
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isAuthenticated]);

  const value: TodoContextType = {
    todos,
    selectedDate,
    viewMode,
    isLoading,
    error,
    loadTodosForDate,
    loadTodosForDateRange,
    createTodo,
    updateTodoText,
    updateTodoPosition,
    completeTodo,
    deleteTodo,
    setViewMode,
    changeDate,
    clearError,
  };

  return <TodoContext.Provider value={value}>{children}</TodoContext.Provider>;
};

// Custom hook to use todo context
export const useTodos = (): TodoContextType => {
  const context = useContext(TodoContext);
  if (context === undefined) {
    throw new Error('useTodos must be used within a TodoProvider');
  }
  return context;
};
