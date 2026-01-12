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

const TodoList: React.FC<TodoListProps> = ({ todos: initialTodos, date, enableDragContext = true, activeId: parentActiveId, overId: parentOverId, suppressPlaceholders = false }) => {
  const { updateTodoPosition, setTodoInMoveMode, todoInMoveMode } = useTodos();
  const [localActiveId, setLocalActiveId] = useState<string | null>(null);
  const [localOverId, setLocalOverId] = useState<string | null>(null);
  const longPressTimerRef = React.useRef<number | null>(null);
  const isLongPressRef = React.useRef<boolean>(false);

  // Use parent's activeId/overId if not managing own context, otherwise use local state
  const activeId = enableDragContext ? localActiveId : parentActiveId;
  const overId = enableDragContext ? localOverId : parentOverId;

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

  // Check if we are in "Reorder Mode" for this specific list
  const isReorderMode = useMemo(() => {
    if (!todoInMoveMode) return false;
    
    // Check if the moving todo belongs to this list's date
    // We compare the date strings to ensure match
    // Note: virtual todos might not have 'assignedDate' set to this date if they are future instances? 
    // Actually virtuals have assignedDate == instanceDate usually.
    // Let's rely on finding the todo in the passed 'todos' array
    return sortedTodos.some(t => isSameTodo(t, todoInMoveMode));
  }, [todoInMoveMode, sortedTodos]);

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

  const handleReorder = async (newIndex: number) => {
    if (!todoInMoveMode) return;

    // Find the current index of the todo being moved
    const currentIndex = sortedTodos.findIndex(t => isSameTodo(t, todoInMoveMode));
    
    if (currentIndex === -1) return;

    try {
      // Exit move mode immediately for better UX
      setTodoInMoveMode(null);
      
      await updateTodoPosition(
        todoInMoveMode.id!,
        newIndex,
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

  const content = (
    <>
      <div className="todo-list-container">
        <div className={`todo-list ${isReorderMode ? 'reorder-mode' : ''}`}>
          
          {/* Render ReorderTarget at the very top (index 0) */}
          {isReorderMode && (
            <ReorderTarget 
              index={0} 
              onSelect={handleReorder}
              // Hide if selected todo is at index 0
              isHidden={isSameTodo(sortedTodos[0], todoInMoveMode)}
            />
          )}

          <SortableContext
            items={sortedTodos.map(getTodoId)}
            strategy={verticalListSortingStrategy}
            // Disable sortable context strategy if in reorder mode to prevent interference
            // (Though disabling sensors above might be enough)
          >
            {sortedTodos.map((todo, index) => {
              const todoId = getTodoId(todo);
              const isActive = activeId === todoId;
              const showPlaceholderAbove = !suppressPlaceholders && overId === todoId && activeId !== todoId;
              const isInMoveMode = isSameTodo(todoInMoveMode, todo);

              // Determine if next target should be hidden
              // Hidden if:
              // 1. This todo is the selected one (moving below self is no-op)
              // 2. Next todo is the selected one (moving above self is no-op)
              const nextTodo = sortedTodos[index + 1];
              const isNextHidden = isInMoveMode || (nextTodo && isSameTodo(nextTodo, todoInMoveMode));

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
                      showPlaceholderAbove={showPlaceholderAbove}
                    />
                  </div>
                  
                  {/* Render ReorderTarget after each item (index + 1) */}
                  {isReorderMode && (
                    <ReorderTarget 
                      index={index + 1} 
                      onSelect={handleReorder}
                      isHidden={!!isNextHidden}
                    />
                  )}
                </React.Fragment>
              );
            })}
          </SortableContext>

          {/* Add new todo input - hide in reorder mode to reduce clutter? */}
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
