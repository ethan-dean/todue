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
  if (todo.id !== null) {
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
}

const TodoList: React.FC<TodoListProps> = ({ todos: initialTodos, date }) => {
  const { updateTodoPosition } = useTodos();
  const [activeId, setActiveId] = useState<string | null>(null);
  const [overId, setOverId] = useState<string | null>(null);

  // Keep todos sorted: incomplete first (by position), then completed (by position)
  const sortedTodos = useMemo(() => {
    return [...initialTodos].sort((a, b) => {
      // Completed todos always go to the bottom
      if (a.isCompleted !== b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      // Within the same completion status, sort by position
      return a.position - b.position;
    });
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
    setActiveId(event.active.id as string);
  };

  const handleDragOver = (event: { over: { id: string } | null }) => {
    setOverId(event.over?.id || null);
  };

  const handleDragEnd = async (event: DragEndEvent) => {
    const { active, over } = event;

    setActiveId(null);
    setOverId(null);

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
        todo.instanceDate
      );
    } catch (err) {
      console.error('Failed to update todo position:', err);
    }
  };

  const handleDragCancel = () => {
    setActiveId(null);
    setOverId(null);
  };

  // Find the active todo for the drag overlay
  const activeTodo = activeId
    ? sortedTodos.find((t) => getTodoId(t) === activeId)
    : null;

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCenter}
      onDragStart={handleDragStart}
      onDragOver={handleDragOver}
      onDragEnd={handleDragEnd}
      onDragCancel={handleDragCancel}
    >
      <div className="todo-list-container">
        <div className="todo-list">
          <SortableContext
            items={sortedTodos.map(getTodoId)}
            strategy={verticalListSortingStrategy}
          >
            {sortedTodos.map((todo) => {
              const todoId = getTodoId(todo);
              const isActive = activeId === todoId;
              const showPlaceholderAbove = overId === todoId && activeId !== todoId;

              return (
                <SortableTodoItem
                  key={todoId}
                  todo={todo}
                  isActive={isActive}
                  showPlaceholderAbove={showPlaceholderAbove}
                />
              );
            })}
          </SortableContext>

          {/* Add new todo input */}
          <InlineAddTodo date={date} />
        </div>
      </div>

      {/* Drag overlay - shows the todo being dragged following the cursor */}
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
    </DndContext>
  );
};

export default TodoList;
