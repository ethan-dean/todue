import React, { createContext, useContext, useState, useEffect, useCallback, useRef, type ReactNode } from 'react';
import type { LaterList, LaterListTodo, WebSocketMessage } from '../types';
import { WebSocketMessageType } from '../types';
import { laterListApi } from '../services/laterListApi';
import { websocketService } from '../services/websocketService';
import { handleApiError } from '../services/api';
import { useAuth } from './AuthContext';

interface LaterListContextType {
  lists: LaterList[];
  currentListId: number | null;
  todos: Map<number, LaterListTodo[]>; // Map of listId -> todos
  isLoading: boolean;
  error: string | null;
  loadLists: () => Promise<void>;
  loadTodosForList: (listId: number) => Promise<void>;
  createList: (listName: string) => Promise<LaterList>;
  updateListName: (listId: number, newName: string) => Promise<void>;
  deleteList: (listId: number) => Promise<void>;
  createTodo: (listId: number, text: string) => Promise<void>;
  updateTodoText: (listId: number, todoId: number, text: string) => Promise<void>;
  updateTodoPosition: (listId: number, todoId: number, position: number) => Promise<void>;
  completeTodo: (listId: number, todoId: number) => Promise<void>;
  uncompleteTodo: (listId: number, todoId: number) => Promise<void>;
  deleteTodo: (listId: number, todoId: number) => Promise<void>;
  setCurrentListId: (listId: number | null) => void;
  clearError: () => void;
}

const LaterListContext = createContext<LaterListContextType | undefined>(undefined);

interface LaterListProviderProps {
  children: ReactNode;
}

export const LaterListProvider: React.FC<LaterListProviderProps> = ({ children }) => {
  const { isAuthenticated } = useAuth();
  const [lists, setLists] = useState<LaterList[]>([]);
  const [currentListId, setCurrentListId] = useState<number | null>(null);
  const [todos, setTodos] = useState<Map<number, LaterListTodo[]>>(new Map());
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  // Track when mutations start to ignore stale fetches
  const lastMutationTimeRef = useRef<number>(0);

  // Refs for WebSocket handler
  const currentListIdRef = useRef(currentListId);
  useEffect(() => {
    currentListIdRef.current = currentListId;
  }, [currentListId]);

  const loadLists = useCallback(async (silent: boolean = false): Promise<void> => {
    if (!silent) {
      setIsLoading(true);
    }
    setError(null);
    try {
      const fetchedLists = await laterListApi.getAllLists();
      setLists(fetchedLists);
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      console.error('Failed to load lists:', err);
    } finally {
      if (!silent) {
        setIsLoading(false);
      }
    }
  }, []);

  const loadTodosForList = useCallback(async (listId: number, silent: boolean = false): Promise<void> => {
    const fetchStartTime = Date.now();

    if (!silent) {
      setIsLoading(true);
    }
    setError(null);
    try {
      const fetchedTodos = await laterListApi.getTodosForList(listId);

      // Check if a mutation happened after this fetch started
      if (fetchStartTime < lastMutationTimeRef.current) {
        console.log('Ignoring stale fetch for list:', listId);
        return;
      }

      setTodos((prevTodos) => {
        const newTodos = new Map(prevTodos);
        newTodos.set(listId, fetchedTodos);
        return newTodos;
      });
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      console.error('Failed to load todos for list:', err);
    } finally {
      if (!silent) {
        setIsLoading(false);
      }
    }
  }, []);

  const createList = async (listName: string): Promise<LaterList> => {
    lastMutationTimeRef.current = Date.now();
    setError(null);
    try {
      const newList = await laterListApi.createList(listName);
      setLists((prevLists) => [...prevLists, newList].sort((a, b) => a.listName.localeCompare(b.listName)));
      return newList;
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const updateListName = async (listId: number, newName: string): Promise<void> => {
    lastMutationTimeRef.current = Date.now();

    // Optimistic update
    setLists((prevLists) =>
      prevLists
        .map((l) => (l.id === listId ? { ...l, listName: newName } : l))
        .sort((a, b) => a.listName.localeCompare(b.listName))
    );

    setError(null);
    try {
      await laterListApi.updateListName(listId, newName);
    } catch (err) {
      // Rollback on error
      await loadLists(true);
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const deleteList = async (listId: number): Promise<void> => {
    lastMutationTimeRef.current = Date.now();

    // Optimistic update
    setLists((prevLists) => prevLists.filter((l) => l.id !== listId));
    setTodos((prevTodos) => {
      const newTodos = new Map(prevTodos);
      newTodos.delete(listId);
      return newTodos;
    });

    setError(null);
    try {
      await laterListApi.deleteList(listId);
      if (currentListId === listId) {
        setCurrentListId(null);
      }
    } catch (err) {
      // Rollback on error
      await loadLists(true);
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const createTodo = async (listId: number, text: string): Promise<void> => {
    lastMutationTimeRef.current = Date.now();
    setError(null);
    try {
      const newTodo = await laterListApi.createTodo(listId, text);
      setTodos((prevTodos) => {
        const newTodos = new Map(prevTodos);
        const listTodos = newTodos.get(listId) || [];
        newTodos.set(listId, [...listTodos, newTodo]);
        return newTodos;
      });
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const updateTodoText = async (listId: number, todoId: number, text: string): Promise<void> => {
    lastMutationTimeRef.current = Date.now();

    // Optimistic update
    setTodos((prevTodos) => {
      const newTodos = new Map(prevTodos);
      const listTodos = newTodos.get(listId) || [];
      newTodos.set(
        listId,
        listTodos.map((t) => (t.id === todoId ? { ...t, text } : t))
      );
      return newTodos;
    });

    setError(null);
    try {
      await laterListApi.updateTodoText(listId, todoId, text);
    } catch (err) {
      await loadTodosForList(listId, true);
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const updateTodoPosition = async (listId: number, todoId: number, newPosition: number): Promise<void> => {
    lastMutationTimeRef.current = Date.now();

    // Optimistic update
    setTodos((prevTodos) => {
      const newTodos = new Map(prevTodos);
      const listTodos = [...(newTodos.get(listId) || [])];
      const sortedList = listTodos.sort((a, b) => a.position - b.position);

      const oldIndex = sortedList.findIndex((t) => t.id === todoId);
      if (oldIndex === -1 || oldIndex === newPosition) {
        return prevTodos;
      }

      const [movedTodo] = sortedList.splice(oldIndex, 1);
      sortedList.splice(newPosition, 0, movedTodo);

      // Update positions
      const reorderedList = sortedList.map((todo, index) => ({
        ...todo,
        position: index + 1,
      }));

      newTodos.set(listId, reorderedList);
      return newTodos;
    });

    setError(null);
    try {
      await laterListApi.updateTodoPosition(listId, todoId, newPosition);
    } catch (err) {
      await loadTodosForList(listId, true);
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const completeTodo = async (listId: number, todoId: number): Promise<void> => {
    lastMutationTimeRef.current = Date.now();

    // Optimistic update
    setTodos((prevTodos) => {
      const newTodos = new Map(prevTodos);
      const listTodos = [...(newTodos.get(listId) || [])];
      const sortedList = listTodos.sort((a, b) => a.position - b.position);

      const oldIndex = sortedList.findIndex((t) => t.id === todoId);
      if (oldIndex === -1) return prevTodos;

      // Find first completed todo position
      let firstCompletedIndex = sortedList.length;
      for (let i = 0; i < sortedList.length; i++) {
        if (sortedList[i].isCompleted) {
          firstCompletedIndex = i;
          break;
        }
      }

      // Mark as completed and move
      const movedTodo = sortedList.splice(oldIndex, 1)[0];
      movedTodo.isCompleted = true;
      movedTodo.completedAt = new Date().toISOString();

      const newIndex = firstCompletedIndex > oldIndex ? firstCompletedIndex - 1 : firstCompletedIndex;
      sortedList.splice(newIndex, 0, movedTodo);

      // Renumber
      const startIdx = Math.min(oldIndex, newIndex);
      const endIdx = Math.max(oldIndex, newIndex);
      for (let i = startIdx; i <= endIdx; i++) {
        sortedList[i].position = i + 1;
      }

      newTodos.set(listId, sortedList);
      return newTodos;
    });

    setError(null);
    try {
      await laterListApi.completeTodo(listId, todoId);
    } catch (err) {
      await loadTodosForList(listId, true);
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const uncompleteTodo = async (listId: number, todoId: number): Promise<void> => {
    lastMutationTimeRef.current = Date.now();

    // Optimistic update
    setTodos((prevTodos) => {
      const newTodos = new Map(prevTodos);
      const listTodos = [...(newTodos.get(listId) || [])];
      const sortedList = listTodos.sort((a, b) => a.position - b.position);

      const oldIndex = sortedList.findIndex((t) => t.id === todoId);
      if (oldIndex === -1) return prevTodos;

      // Find first completed todo position (excluding current)
      let firstCompletedIndex = sortedList.length;
      for (let i = 0; i < sortedList.length; i++) {
        if (sortedList[i].isCompleted && sortedList[i].id !== todoId) {
          firstCompletedIndex = i;
          break;
        }
      }

      // Mark as incomplete and move
      const movedTodo = sortedList.splice(oldIndex, 1)[0];
      movedTodo.isCompleted = false;
      movedTodo.completedAt = null;

      const newIndex = firstCompletedIndex > oldIndex ? firstCompletedIndex - 1 : firstCompletedIndex;
      sortedList.splice(newIndex, 0, movedTodo);

      // Renumber
      const startIdx = Math.min(oldIndex, newIndex);
      const endIdx = Math.max(oldIndex, newIndex);
      for (let i = startIdx; i <= endIdx; i++) {
        sortedList[i].position = i + 1;
      }

      newTodos.set(listId, sortedList);
      return newTodos;
    });

    setError(null);
    try {
      await laterListApi.uncompleteTodo(listId, todoId);
    } catch (err) {
      await loadTodosForList(listId, true);
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const deleteTodo = async (listId: number, todoId: number): Promise<void> => {
    lastMutationTimeRef.current = Date.now();

    // Optimistic update
    setTodos((prevTodos) => {
      const newTodos = new Map(prevTodos);
      const listTodos = newTodos.get(listId) || [];
      newTodos.set(
        listId,
        listTodos.filter((t) => t.id !== todoId)
      );
      return newTodos;
    });

    setError(null);
    try {
      await laterListApi.deleteTodo(listId, todoId);
    } catch (err) {
      await loadTodosForList(listId, true);
      const errorMessage = handleApiError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  const clearError = (): void => {
    setError(null);
  };

  // WebSocket message handler
  const handleWebSocketMessage = useCallback(
    (message: WebSocketMessage): void => {
      if (message.type !== WebSocketMessageType.LATER_LIST_CHANGED) return;

      console.log('WebSocket LATER_LIST_CHANGED:', message.data);

      const { listId, action } = message.data as { listId?: number; action: string };

      setTimeout(() => {
        switch (action) {
          case 'LIST_CREATED':
          case 'LIST_UPDATED':
          case 'LIST_DELETED':
            // Refetch all lists
            loadLists(true);
            break;
          case 'TODOS_UPDATED':
            // Refetch todos for the specific list if it's currently viewed
            if (listId && currentListIdRef.current === listId) {
              loadTodosForList(listId, true);
            }
            break;
        }
      }, 300);
    },
    [loadLists, loadTodosForList]
  );

  // Load lists when authenticated
  useEffect(() => {
    if (isAuthenticated) {
      loadLists();
    }
  }, [isAuthenticated, loadLists]);

  // Load todos when currentListId changes
  useEffect(() => {
    if (isAuthenticated && currentListId !== null) {
      loadTodosForList(currentListId);
    }
  }, [isAuthenticated, currentListId, loadTodosForList]);

  // Subscribe to WebSocket updates
  useEffect(() => {
    if (!isAuthenticated) return;

    let unsubscribe: (() => void) | null = null;

    websocketService.onConnectionEstablished(() => {
      unsubscribe = websocketService.subscribe(handleWebSocketMessage);
    });

    return () => {
      if (unsubscribe) {
        unsubscribe();
      }
    };
  }, [isAuthenticated, handleWebSocketMessage]);

  const value: LaterListContextType = {
    lists,
    currentListId,
    todos,
    isLoading,
    error,
    loadLists,
    loadTodosForList,
    createList,
    updateListName,
    deleteList,
    createTodo,
    updateTodoText,
    updateTodoPosition,
    completeTodo,
    uncompleteTodo,
    deleteTodo,
    setCurrentListId,
    clearError,
  };

  return <LaterListContext.Provider value={value}>{children}</LaterListContext.Provider>;
};

export const useLaterLists = (): LaterListContextType => {
  const context = useContext(LaterListContext);
  if (context === undefined) {
    throw new Error('useLaterLists must be used within a LaterListProvider');
  }
  return context;
};
