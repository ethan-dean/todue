import React, { useState, useMemo } from 'react';
import {
  DndContext,
  closestCenter,
  PointerSensor,
  useSensor,
  useSensors,
  DragOverlay,
  type DragEndEvent,
  type DragStartEvent,
} from '@dnd-kit/core';
import {
  SortableContext,
  verticalListSortingStrategy,
  useSortable,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import type { Todo } from '../types';
import { useTodos } from '../context/TodoContext';
import TodoItem from './TodoItem';
import InlineAddTodo from './InlineAddTodo';

// Generate unique ID for sortable items
const getTodoId = (todo: Todo): string => {
  if (todo.id != null) { // Checks both null and undefined
    return `todo-${todo.id}`;
  }
  // Virtual todos: use recurringTodoId + instanceDate
  return `virtual-${todo.recurringTodoId}-${todo.instanceDate}`;
};

interface SortableTodoItemProps {
  todo: Todo;
  isActive: boolean;
  showPlaceholderAbove: boolean;
}

const SortableTodoItem: React.FC<SortableTodoItemProps> = ({
  todo,
  isActive,
  showPlaceholderAbove,
}) => {
  const { deleteTodo } = useTodos();
  const [isDeleting, setIsDeleting] = useState(false);

  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
  } = useSortable({ id: getTodoId(todo) });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };

  const handleDelete = async (deleteAllFuture?: boolean) => {
    if (isDeleting) return;

    setIsDeleting(true);
    try {
      await deleteTodo(
        todo.id!,
        todo.isVirtual,
        todo.recurringTodoId,
        todo.instanceDate,
        deleteAllFuture
      );
    } catch (err) {
      console.error('Failed to delete todo:', err);
    } finally {
      setIsDeleting(false);
    }
  };

  return (
    <div className="draggable-todo-wrapper">
      {/* Placeholder box showing where item will drop */}
      {showPlaceholderAbove && !isActive && (
        <div className="drop-placeholder"></div>
      )}

      {/* The actual todo item */}
      <div
        ref={setNodeRef}
        style={style}
        className={isActive ? 'todo-placeholder' : ''}
        {...attributes}
        {...listeners}
      >
        <TodoItem todo={todo} onDelete={handleDelete} />
      </div>
    </div>
  );
};

interface TodoListProps {
  todos: Todo[];
  date: Date;
  enableDragContext?: boolean; // Whether to wrap in its own DndContext
  activeId?: string | null; // From parent when enableDragContext=false
  overId?: string | null; // From parent when enableDragContext=false
  suppressPlaceholders?: boolean; // Hide placeholders when dragging from different day
}

const TodoList: React.FC<TodoListProps> = ({ todos: initialTodos, date, enableDragContext = true, activeId: parentActiveId, overId: parentOverId, suppressPlaceholders = false }) => {
  const { updateTodoPosition, setTodoInMoveMode, todoInMoveMode } = useTodos();
  const [localActiveId, setLocalActiveId] = useState<string | null>(null);
  const [localOverId, setLocalOverId] = useState<string | null>(null);
  const longPressTimerRef = React.useRef<number | null>(null);

  // Use parent's activeId/overId if not managing own context, otherwise use local state
  const activeId = enableDragContext ? localActiveId : parentActiveId;
  const overId = enableDragContext ? localOverId : parentOverId;

  // Sort by position only - position determines everything including completion status
  const sortedTodos = useMemo(() => {
    return [...initialTodos].sort((a, b) => a.position - b.position);
  }, [initialTodos]);

  // Configure drag sensors
  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 8, // Require 8px movement before dragging starts
      },
    })
  );

  const handleDragStart = (event: DragStartEvent) => {
    setLocalActiveId(event.active.id as string);
  };

  const handleDragOver = (event: { over: { id: string } | null }) => {
    setLocalOverId(event.over?.id || null);
  };

  const handleDragEnd = async (event: DragEndEvent) => {
    const { active, over } = event;

    setLocalActiveId(null);
    setLocalOverId(null);

    if (!over || active.id === over.id) {
      return;
    }

    const oldIndex = sortedTodos.findIndex((t) => getTodoId(t) === active.id);
    const newIndex = sortedTodos.findIndex((t) => getTodoId(t) === over.id);

    if (oldIndex === -1 || newIndex === -1) {
      console.error('Could not find todo indices for drag and drop');
      return;
    }

    const todo = sortedTodos[oldIndex];

    try {
      await updateTodoPosition(
        todo.id!,
        newIndex,
        todo.isVirtual,
        todo.recurringTodoId,
        todo.instanceDate,
        todo.assignedDate
      );
    } catch (err) {
      console.error('Failed to update todo position:', err);
    }
  };

  const handleDragCancel = () => {
    setLocalActiveId(null);
    setLocalOverId(null);
  };

  // Long-press handlers for mobile move mode
  const handleTouchStart = (todo: Todo) => {
    longPressTimerRef.current = window.setTimeout(() => {
      // Trigger move mode
      setTodoInMoveMode(todo);
      // Haptic feedback on mobile
      if (navigator.vibrate) {
        navigator.vibrate(50);
      }
    }, 500); // 500ms long-press
  };

  const handleTouchEnd = () => {
    if (longPressTimerRef.current) {
      clearTimeout(longPressTimerRef.current);
      longPressTimerRef.current = null;
    }
  };

  // Find the active todo for the drag overlay
  const activeTodo = activeId
    ? sortedTodos.find((t) => getTodoId(t) === activeId)
    : null;

  const content = (
    <>
      <div className="todo-list-container">
        <div className="todo-list">
          <SortableContext
            items={sortedTodos.map(getTodoId)}
            strategy={verticalListSortingStrategy}
          >
            {sortedTodos.map((todo) => {
              const todoId = getTodoId(todo);
              const isActive = activeId === todoId;
              const showPlaceholderAbove = !suppressPlaceholders && overId === todoId && activeId !== todoId;
              const isInMoveMode = todoInMoveMode?.id === todo.id &&
                                   todoInMoveMode?.recurringTodoId === todo.recurringTodoId &&
                                   todoInMoveMode?.instanceDate === todo.instanceDate;

              return (
                <div
                  key={todoId}
                  onTouchStart={() => handleTouchStart(todo)}
                  onTouchEnd={handleTouchEnd}
                  onTouchCancel={handleTouchEnd}
                  className={isInMoveMode ? 'todo-in-move-mode' : ''}
                >
                  <SortableTodoItem
                    todo={todo}
                    isActive={isActive}
                    showPlaceholderAbove={showPlaceholderAbove}
                  />
                </div>
              );
            })}
          </SortableContext>

          {/* Add new todo input */}
          <InlineAddTodo date={date} />
        </div>
      </div>

      {/* Drag overlay - shows the todo being dragged following the cursor */}
      {enableDragContext && (
        <DragOverlay>
          {activeTodo ? (
            <div className="todo-item drag-preview" style={{ cursor: 'grabbing' }}>
              <div className="todo-checkbox">
                <input type="checkbox" checked={activeTodo.isCompleted} readOnly />
              </div>
              <div className="todo-text">{activeTodo.text}</div>
              <div className="todo-actions"></div>
            </div>
          ) : null}
        </DragOverlay>
      )}
    </>
  );

  // Only wrap in DndContext if enableDragContext is true (single-day view)
  // In multi-day view, parent provides the DndContext
  if (enableDragContext) {
    return (
      <DndContext
        sensors={sensors}
        collisionDetection={closestCenter}
        onDragStart={handleDragStart}
        onDragOver={handleDragOver}
        onDragEnd={handleDragEnd}
        onDragCancel={handleDragCancel}
      >
        {content}
      </DndContext>
    );
  }

  return content;
};

export default TodoList;
