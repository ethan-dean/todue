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
  type DragOverEvent,
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
}

const SortableTodoItem: React.FC<SortableTodoItemProps> = ({
  todo,
  isActive,
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
        todo.id,
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
    <div
      ref={setNodeRef}
      style={style}
      className={`sortable-todo-wrapper ${isActive ? 'todo-placeholder' : ''}`}
      {...attributes}
      {...listeners}
    >
      <TodoItem todo={todo} onDelete={handleDelete} />
    </div>
  );
};

// Reorder Target Component
interface ReorderTargetProps {
  index: number;
  onSelect: (index: number) => void;
  isHidden: boolean;
}

const ReorderTarget: React.FC<ReorderTargetProps> = ({ index, onSelect, isHidden }) => {
  if (isHidden) return <div className="reorder-target hidden" />;

  return (
    <div className="reorder-target" onClick={() => onSelect(index)}>
      <div className="reorder-button" />
      <div className="reorder-line" />
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

const TodoList: React.FC<TodoListProps> = ({ todos: initialTodos, date, enableDragContext = true, activeId: parentActiveId, overId: _parentOverId, suppressPlaceholders: _suppressPlaceholders = false }) => {
  const { updateTodoPosition, setTodoInMoveMode, todoInMoveMode } = useTodos();
  const [localActiveId, setLocalActiveId] = useState<string | null>(null);
  const [, setLocalOverId] = useState<string | null>(null);
  const longPressTimerRef = React.useRef<number | null>(null);
  const isLongPressRef = React.useRef<boolean>(false);

  // Use parent's activeId if not managing own context, otherwise use local state
  const activeId = enableDragContext ? localActiveId : parentActiveId;

  // Helper to compare todos
  const isSameTodo = (a: Todo | null, b: Todo | null): boolean => {
    if (!a || !b) return false;
    // Check IDs first
    if (a.id != null && b.id != null) {
      return a.id === b.id;
    }
    // Fallback to recurrence ID + instance date
    return a.recurringTodoId === b.recurringTodoId &&
           a.instanceDate === b.instanceDate;
  };

  // Sort by position only - position determines everything including completion status
  const sortedTodos = useMemo(() => {
    return [...initialTodos].sort((a, b) => a.position - b.position);
  }, [initialTodos]);

  // Split into incomplete and complete sections for separate drag contexts
  const incompleteTodos = useMemo(() =>
    sortedTodos.filter(t => !t.isCompleted), [sortedTodos]);
  const completeTodos = useMemo(() =>
    sortedTodos.filter(t => t.isCompleted), [sortedTodos]);

  // Check if we are in "Reorder Mode" for this specific list
  const isReorderMode = useMemo(() => {
    if (!todoInMoveMode) return false;

    // Check if the moving todo belongs to this list's date
    return incompleteTodos.some(t => isSameTodo(t, todoInMoveMode)) ||
           completeTodos.some(t => isSameTodo(t, todoInMoveMode));
  }, [todoInMoveMode, incompleteTodos, completeTodos]);

  // Determine which section the todoInMoveMode belongs to
  const moveModeInIncomplete = useMemo(() => {
    if (!todoInMoveMode) return false;
    return incompleteTodos.some(t => isSameTodo(t, todoInMoveMode));
  }, [todoInMoveMode, incompleteTodos]);

  // Configure drag sensors - disable if in reorder mode
  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 8, // Require 8px movement before dragging starts
      },
      // Disable sensors if in reorder mode to prevent conflict
      disabled: isReorderMode,
    })
  );

  const handleDragStart = (event: DragStartEvent) => {
    setLocalActiveId(event.active.id as string);
  };

  const handleDragOver = (event: DragOverEvent) => {
    setLocalOverId(event.over?.id ? String(event.over.id) : null);
  };

  const handleDragEnd = async (event: DragEndEvent) => {
    const { active, over } = event;

    setLocalActiveId(null);
    setLocalOverId(null);

    if (!over || active.id === over.id) {
      return;
    }

    // Determine which section each todo belongs to
    const activeInIncomplete = incompleteTodos.some(t => getTodoId(t) === active.id);
    const overInIncomplete = incompleteTodos.some(t => getTodoId(t) === over.id);

    // Prevent cross-section reordering
    if (activeInIncomplete !== overInIncomplete) return;

    const relevantList = activeInIncomplete ? incompleteTodos : completeTodos;
    const oldIndex = relevantList.findIndex((t) => getTodoId(t) === active.id);
    const newIndex = relevantList.findIndex((t) => getTodoId(t) === over.id);

    if (oldIndex === -1 || newIndex === -1) {
      console.error('Could not find todo indices for drag and drop');
      return;
    }

    const todo = relevantList[oldIndex];

    // Calculate full list index for position update
    const fullListIndex = activeInIncomplete ? newIndex : newIndex + incompleteTodos.length;

    try {
      await updateTodoPosition(
        todo.id!,
        fullListIndex,
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
    isLongPressRef.current = false;
    longPressTimerRef.current = window.setTimeout(() => {
      isLongPressRef.current = true;
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

  const handleTodoClick = (todo: Todo) => {
    // If it was a long press, the click event might fire on release
    // We don't want to immediately deselect what we just selected
    if (isLongPressRef.current) {
      isLongPressRef.current = false;
      return;
    }

    // If already in move mode and we tap the same todo, deselect it
    if (todoInMoveMode && isSameTodo(todoInMoveMode, todo)) {
      setTodoInMoveMode(null);
    }
  };

  const handleReorder = async (newIndex: number, isInCompleteSection: boolean) => {
    if (!todoInMoveMode) return;

    // Prevent cross-section moves
    if (moveModeInIncomplete !== !isInCompleteSection) return;

    // Calculate full list index
    const fullListIndex = isInCompleteSection ? newIndex + incompleteTodos.length : newIndex;

    try {
      // Exit move mode immediately for better UX
      setTodoInMoveMode(null);

      await updateTodoPosition(
        todoInMoveMode.id!,
        fullListIndex,
        todoInMoveMode.isVirtual,
        todoInMoveMode.recurringTodoId,
        todoInMoveMode.instanceDate,
        todoInMoveMode.assignedDate
      );
    } catch (err) {
      console.error('Failed to reorder todo:', err);
    }
  };

  // Find the active todo for the drag overlay
  const activeTodo = activeId
    ? sortedTodos.find((t) => getTodoId(t) === activeId)
    : null;

  // Helper to render a section of todos
  const renderTodoSection = (sectionTodos: Todo[], isCompleteSection: boolean) => {
    return sectionTodos.map((todo, index) => {
      const todoId = getTodoId(todo);
      const isActive = activeId === todoId;
      const isInMoveMode = isSameTodo(todoInMoveMode, todo);

      // Determine if next target should be hidden
      const nextTodo = sectionTodos[index + 1];
      const isNextHidden = isInMoveMode || (nextTodo && isSameTodo(nextTodo, todoInMoveMode));

      // Only show reorder targets if todo in move mode is in the same section
      const showReorderTargets = isReorderMode && (moveModeInIncomplete === !isCompleteSection);

      return (
        <React.Fragment key={todoId}>
          <div
            onTouchStart={() => handleTouchStart(todo)}
            onTouchEnd={handleTouchEnd}
            onTouchCancel={handleTouchEnd}
            onClick={() => handleTodoClick(todo)}
            className={isInMoveMode ? 'todo-in-move-mode' : ''}
          >
            <SortableTodoItem
              todo={todo}
              isActive={isActive}
            />
          </div>

          {/* Render ReorderTarget after each item */}
          {showReorderTargets && (
            <ReorderTarget
              index={index + 1}
              onSelect={(idx) => handleReorder(idx, isCompleteSection)}
              isHidden={!!isNextHidden}
            />
          )}
        </React.Fragment>
      );
    });
  };

  const content = (
    <>
      <div className="todo-list-container">
        <div className={`todo-list ${isReorderMode ? 'reorder-mode' : ''}`}>

          {/* Incomplete section */}
          {isReorderMode && moveModeInIncomplete && (
            <ReorderTarget
              index={0}
              onSelect={(idx) => handleReorder(idx, false)}
              isHidden={isSameTodo(incompleteTodos[0], todoInMoveMode)}
            />
          )}

          <SortableContext
            items={incompleteTodos.map(getTodoId)}
            strategy={verticalListSortingStrategy}
          >
            {renderTodoSection(incompleteTodos, false)}
          </SortableContext>

          {/* Complete section */}
          {isReorderMode && !moveModeInIncomplete && (
            <ReorderTarget
              index={0}
              onSelect={(idx) => handleReorder(idx, true)}
              isHidden={isSameTodo(completeTodos[0], todoInMoveMode)}
            />
          )}

          <SortableContext
            items={completeTodos.map(getTodoId)}
            strategy={verticalListSortingStrategy}
          >
            {renderTodoSection(completeTodos, true)}
          </SortableContext>

          {/* Add new todo input - hide in reorder mode to reduce clutter */}
          {!isReorderMode && <InlineAddTodo date={date} />}
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
