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
  uncompleteTodo: (id: number, isVirtual: boolean, recurringTodoId: number | null, instanceDate: string) => Promise<void>;
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

  // Track when mutations start to ignore stale fetches
  const lastMutationTimeRef = useRef<number>(0);

  // Keep refs in sync with state
  useEffect(() => {
    selectedDateRef.current = selectedDate;
  }, [selectedDate]);

  useEffect(() => {
    viewModeRef.current = viewMode;
  }, [viewMode]);

  // Helper to parse ISO date string (YYYY-MM-DD) to Date object in local timezone
  // Avoids timezone shift issues when using new Date(string) which interprets as UTC
  const parseDateString = useCallback((dateStr: string): Date => {
    const [year, month, day] = dateStr.split('-').map(Number);
    return new Date(year, month - 1, day);
  }, []);

  // Helper function for deep todo comparison
  const areTodosEqual = (todos1: Todo[], todos2: Todo[]): boolean => {
    if (todos1.length !== todos2.length) return false;

    // Sort both arrays by id (or instanceDate for virtuals) to ensure order doesn't matter
    const sorted1 = [...todos1].sort((a, b) => {
      const idA = a.id ?? a.instanceDate;
      const idB = b.id ?? b.instanceDate;
      return String(idA).localeCompare(String(idB));
    });

    const sorted2 = [...todos2].sort((a, b) => {
      const idA = a.id ?? a.instanceDate;
      const idB = b.id ?? b.instanceDate;
      return String(idA).localeCompare(String(idB));
    });

    // Compare each todo's properties
    return sorted1.every((todo1, index) => {
      const todo2 = sorted2[index];
      // Note: We don't compare completedAt because frontend/backend timestamps will differ
      // The isCompleted boolean is what matters for equality

      return (
        todo1.id === todo2.id &&
        todo1.text === todo2.text &&
        todo1.position === todo2.position &&
        todo1.isCompleted === todo2.isCompleted &&
        todo1.assignedDate === todo2.assignedDate &&
        todo1.instanceDate === todo2.instanceDate &&
        todo1.recurringTodoId === todo2.recurringTodoId &&
        todo1.isRolledOver === todo2.isRolledOver &&
        todo1.isVirtual === todo2.isVirtual
      );
    });
  };

  const loadTodosForDate = useCallback(async (date: Date, silent: boolean = false): Promise<void> => {
    // Record when this fetch started
    const fetchStartTime = Date.now();

    // Only show loading state if not silent (e.g., initial load, manual refresh)
    // Silent refetches (from WebSocket) don't clear the UI
    if (!silent) {
      setIsLoading(true);
    }
    setError(null);
    try {
      const dateStr = formatDateForAPI(date);
      const fetchedTodos = await todoApi.getTodosForDate(dateStr);

      // Check if a mutation happened after this fetch started
      if (fetchStartTime < lastMutationTimeRef.current) {
        console.log('Ignoring stale fetch for date:', dateStr, '- mutation happened during fetch');
        return; // Don't update state with stale data
      }

      setTodos((prevTodos) => {
        const currentTodos = prevTodos.get(dateStr);

        // Deep comparison - check if todos are identical
        if (currentTodos && areTodosEqual(currentTodos, fetchedTodos)) {
          console.log('Todos unchanged for date:', dateStr, '- skipping update');
          return prevTodos; // No change - prevents re-render
        }

        console.log('Todos changed for date:', dateStr, '- updating state');

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

  const loadTodosForDateRange = useCallback(async (startDate: Date, endDate: Date, silent: boolean = false): Promise<void> => {
    // Record when this fetch started
    const fetchStartTime = Date.now();

    if (!silent) {
      setIsLoading(true);
    }
    setError(null);
    try {
      const startDateStr = formatDateForAPI(startDate);
      const endDateStr = formatDateForAPI(endDate);
      const fetchedTodos = await todoApi.getTodosForDateRange(startDateStr, endDateStr);

      // Check if a mutation happened after this fetch started
      if (fetchStartTime < lastMutationTimeRef.current) {
        console.log('Ignoring stale fetch for date range:', startDateStr, '-', endDateStr, '- mutation happened during fetch');
        return; // Don't update state with stale data
      }

      // Group todos by assigned_date
      const todosByDate = new Map<string, Todo[]>();
      fetchedTodos.forEach((todo) => {
        const dateKey = todo.assignedDate;
        if (!todosByDate.has(dateKey)) {
          todosByDate.set(dateKey, []);
        }
        todosByDate.get(dateKey)!.push(todo);
      });

      setTodos((prevTodos) => {
        const newTodos = new Map(prevTodos);
        let hasChanges = false;

        // Compare each date's todos
        todosByDate.forEach((fetchedTodosForDate, dateKey) => {
          const currentTodosForDate = prevTodos.get(dateKey);

          // Deep comparison - check if todos are identical
          if (!currentTodosForDate || !areTodosEqual(currentTodosForDate, fetchedTodosForDate)) {
            console.log('Todos changed for date:', dateKey, '- updating state');
            newTodos.set(dateKey, fetchedTodosForDate);
            hasChanges = true;
          } else {
            console.log('Todos unchanged for date:', dateKey, '- skipping update');
          }
        });

        // If no changes detected, return previous state to prevent re-render
        return hasChanges ? newTodos : prevTodos;
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

  const loadTodosForCurrentView = useCallback(async (silent: boolean = false): Promise<void> => {
    if (viewMode === 1) {
      await loadTodosForDate(selectedDate, silent);
    } else {
      const dates = getDateRange(selectedDate, viewMode);
      await loadTodosForDateRange(dates[0], dates[dates.length - 1], silent);
    }
  }, [viewMode, selectedDate, loadTodosForDate, loadTodosForDateRange]);

  const createTodo = async (text: string, date: Date): Promise<void> => {
    // Record mutation timestamp
    lastMutationTimeRef.current = Date.now();

    setError(null);
    try {
      const dateStr = formatDateForAPI(date);

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
    // Record mutation timestamp
    lastMutationTimeRef.current = Date.now();

    setError(null);
    try {
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
    // Record mutation timestamp
    lastMutationTimeRef.current = Date.now();

    setError(null);

    // Optimistically update local state first for instant feedback
    setTodos((prevTodos) => {
      const newTodos = new Map(prevTodos);
      const dateList = newTodos.get(instanceDate) || [];

      // Find the todo being moved
      const todoIndex = dateList.findIndex((t) =>
        isVirtual
          ? t.isVirtual && t.recurringTodoId === recurringTodoId && t.instanceDate === instanceDate
          : t.id === id
      );

      if (todoIndex === -1) {
        return prevTodos; // Todo not found, no change
      }

      // Sort by current position to get correct order
      const sortedList = [...dateList].sort((a, b) => a.position - b.position);

      // Find the todo in the sorted list
      const sortedIndex = sortedList.findIndex((t) =>
        isVirtual
          ? t.isVirtual && t.recurringTodoId === recurringTodoId && t.instanceDate === instanceDate
          : t.id === id
      );

      if (sortedIndex === -1 || sortedIndex === position) {
        return prevTodos; // Already in correct position
      }

      // Remove from old position and insert at new position
      const [movedTodo] = sortedList.splice(sortedIndex, 1);
      sortedList.splice(position, 0, movedTodo);

      // Update positions to match new order (1, 2, 3, 4...)
      const reorderedList = sortedList.map((todo, index) => ({
        ...todo,
        position: index + 1,
      }));

      newTodos.set(instanceDate, reorderedList);
      return newTodos;
    });

    try {
      if (isVirtual && recurringTodoId) {
        await todoApi.updateVirtualTodoPosition(recurringTodoId, instanceDate, position);
      } else {
        await todoApi.updateTodoPosition(id, position);
      }

      // Don't update state with server response - trust the optimistic update
      // The optimistic update already reordered the entire list correctly
    } catch (err) {
      // On error, refetch to get the correct state from server
      await loadTodosForDate(parseDateString(instanceDate), true);

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
    // Record mutation timestamp
    lastMutationTimeRef.current = Date.now();

    setError(null);

    // Optimistically update local state first for instant feedback
    setTodos((prevTodos) => {
      const newTodos = new Map(prevTodos);
      const dateList = newTodos.get(instanceDate) || [];

      // Sort by position
      const sortedList = [...dateList].sort((a, b) => a.position - b.position);

      // Find the todo being completed
      const oldIndex = sortedList.findIndex((t) =>
        isVirtual
          ? t.isVirtual && t.recurringTodoId === recurringTodoId && t.instanceDate === instanceDate
          : t.id === id
      );

      if (oldIndex === -1) {
        return prevTodos; // Todo not found, no change
      }

      // Find first completed todo position (or end if none)
      let firstCompletedIndex = sortedList.length;
      for (let i = 0; i < sortedList.length; i++) {
        if (sortedList[i].isCompleted) {
          firstCompletedIndex = i;
          break;
        }
      }

      // Mark as completed and move to top of completed section
      const movedTodo = sortedList.splice(oldIndex, 1)[0];
      movedTodo.isCompleted = true;
      movedTodo.completedAt = new Date().toISOString();

      // Adjust index if we're moving forward
      const newIndex = firstCompletedIndex > oldIndex ? firstCompletedIndex - 1 : firstCompletedIndex;
      sortedList.splice(newIndex, 0, movedTodo);

      // Renumber affected range (1, 2, 3, 4...)
      const startIdx = Math.min(oldIndex, newIndex);
      const endIdx = Math.max(oldIndex, newIndex);
      for (let i = startIdx; i <= endIdx; i++) {
        sortedList[i].position = i + 1;
      }

      newTodos.set(instanceDate, sortedList);
      return newTodos;
    });

    try {
      if (isVirtual && recurringTodoId) {
        await todoApi.completeVirtualTodo(recurringTodoId, instanceDate);
      } else {
        await todoApi.completeTodo(id);
      }

      // Don't update state with server response - trust the optimistic update
    } catch (err) {
      // On error, refetch to get the correct state from server
      await loadTodosForDate(parseDateString(instanceDate), true);

      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const uncompleteTodo = async (
    id: number,
    isVirtual: boolean,
    recurringTodoId: number | null,
    instanceDate: string
  ): Promise<void> => {
    // Record mutation timestamp
    lastMutationTimeRef.current = Date.now();

    setError(null);

    // Optimistically update local state first for instant feedback
    setTodos((prevTodos) => {
      const newTodos = new Map(prevTodos);
      const dateList = newTodos.get(instanceDate) || [];

      // Sort by position
      const sortedList = [...dateList].sort((a, b) => a.position - b.position);

      // Find the todo being uncompleted
      const oldIndex = sortedList.findIndex((t) => t.id === id);

      if (oldIndex === -1) {
        return prevTodos; // Todo not found, no change
      }

      // Find first completed todo position (end of incomplete section)
      let firstCompletedIndex = sortedList.length;
      for (let i = 0; i < sortedList.length; i++) {
        if (sortedList[i].isCompleted && sortedList[i].id !== id) {
          firstCompletedIndex = i;
          break;
        }
      }

      // Mark as incomplete and move to end of incomplete section
      const movedTodo = sortedList.splice(oldIndex, 1)[0];
      movedTodo.isCompleted = false;
      movedTodo.completedAt = null;

      // Adjust index if we removed before the target
      const newIndex = firstCompletedIndex > oldIndex ? firstCompletedIndex - 1 : firstCompletedIndex;
      sortedList.splice(newIndex, 0, movedTodo);

      // Renumber affected range (1, 2, 3, 4...)
      const startIdx = Math.min(oldIndex, newIndex);
      const endIdx = Math.max(oldIndex, newIndex);
      for (let i = startIdx; i <= endIdx; i++) {
        sortedList[i].position = i + 1;
      }

      newTodos.set(instanceDate, sortedList);
      return newTodos;
    });

    try {
      // If todo is completed, it must be materialized (have an ID)
      // So we always use the regular uncomplete endpoint
      await todoApi.uncompleteTodo(id);

      // Don't update state with server response - trust the optimistic update
    } catch (err) {
      // On error, refetch to get the correct state from server
      await loadTodosForDate(parseDateString(instanceDate), true);

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
    // Record mutation timestamp
    lastMutationTimeRef.current = Date.now();

    setError(null);
    try {
      if (isVirtual && recurringTodoId) {
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
            // Small delay to allow database transaction to commit (prevents race condition)
            setTimeout(() => {
              // Always refetch - state comparison will prevent unnecessary updates
              // Use refs to get current values instead of closure values
              if (viewModeRef.current === 1) {
                // Single day view - only refetch if it's the selected date
                if (formatDateForAPI(selectedDateRef.current) === date) {
                  // Silent refetch - comparison prevents flicker if data unchanged
                  loadTodosForDate(parseDateString(date), true);
                }
              } else {
                // Multi-day view - refetch if the date is in visible range
                const dates = getDateRange(selectedDateRef.current, viewModeRef.current);
                const isVisible = dates.some(d => formatDateForAPI(d) === date);
                if (isVisible) {
                  // Silent refetch - comparison prevents flicker if data unchanged
                  loadTodosForDate(parseDateString(date), true);
                }
              }
            }, 500); // 200ms delay to allow transaction commit
          }
        }
        break;

      case WebSocketMessageType.RECURRING_CHANGED:
        // Recurring pattern changed - refetch all currently visible dates
        setTimeout(() => {
          loadTodosForCurrentView(true); // Silent refetch - state comparison prevents flicker
        }, 50); // 50ms delay to allow transaction commit
        break;

      default:
        console.warn('Unknown WebSocket message type:', message.type);
    }
  }, [parseDateString, loadTodosForDate, loadTodosForCurrentView]);

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
    uncompleteTodo,
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
