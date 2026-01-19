import React, { useState, type KeyboardEvent } from 'react';
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
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import type { LaterListTodo } from '../types';
import { useLaterLists } from '../context/LaterListContext';
import LaterListTodoItem from './LaterListTodoItem';

interface SortableTodoItemProps {
  todo: LaterListTodo;
  listId: number;
}

const SortableTodoItem: React.FC<SortableTodoItemProps> = ({ todo, listId }) => {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: `todo-${todo.id}` });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.3 : 1,
  };

  return (
    <div ref={setNodeRef} style={style} {...attributes} {...listeners}>
      <LaterListTodoItem todo={todo} listId={listId} />
    </div>
  );
};

interface LaterListTodoListProps {
  listId: number;
  todos: LaterListTodo[];
}

const LaterListTodoList: React.FC<LaterListTodoListProps> = ({ listId, todos }) => {
  const { createTodo, updateTodoPosition } = useLaterLists();
  const [newTodoText, setNewTodoText] = useState('');
  const [isCreating, setIsCreating] = useState(false);
  const [activeId, setActiveId] = useState<string | null>(null);

  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 8,
      },
    })
  );

  // Sort todos by position
  const sortedTodos = [...todos].sort((a, b) => a.position - b.position);

  const handleCreateTodo = async () => {
    if (newTodoText.trim() === '' || isCreating) return;

    setIsCreating(true);
    try {
      await createTodo(listId, newTodoText.trim());
      setNewTodoText('');
    } catch (err) {
      console.error('Failed to create todo:', err);
    } finally {
      setIsCreating(false);
    }
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      handleCreateTodo();
    }
  };

  const handleDragStart = (event: DragStartEvent) => {
    setActiveId(event.active.id as string);
  };

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;
    setActiveId(null);

    if (!over || active.id === over.id) return;

    const oldIndex = sortedTodos.findIndex((t) => `todo-${t.id}` === active.id);
    const newIndex = sortedTodos.findIndex((t) => `todo-${t.id}` === over.id);

    if (oldIndex === -1 || newIndex === -1) return;

    const todoId = sortedTodos[oldIndex].id;
    updateTodoPosition(listId, todoId, newIndex);
  };

  const activeTodo = activeId
    ? sortedTodos.find((t) => `todo-${t.id}` === activeId)
    : null;

  return (
    <div className="later-list-todo-list">
      {/* Add Todo Input */}
      <div className="add-todo-input-container">
        <div className="add-todo-input">
          <input
            type="text"
            className="todo-input"
            placeholder="Add a new item..."
            value={newTodoText}
            onChange={(e) => setNewTodoText(e.target.value)}
            onKeyDown={handleKeyDown}
            disabled={isCreating}
          />
          <button
            className="btn-add"
            onClick={handleCreateTodo}
            disabled={isCreating || newTodoText.trim() === ''}
          >
            Add
          </button>
        </div>
      </div>

      {/* Todo List */}
      {sortedTodos.length === 0 ? (
        <div className="todo-list-empty">No items yet. Add one above!</div>
      ) : (
        <DndContext
          sensors={sensors}
          collisionDetection={closestCenter}
          onDragStart={handleDragStart}
          onDragEnd={handleDragEnd}
        >
          <SortableContext
            items={sortedTodos.map((t) => `todo-${t.id}`)}
            strategy={verticalListSortingStrategy}
          >
            <div className="todo-list">
              {sortedTodos.map((todo) => (
                <SortableTodoItem key={todo.id} todo={todo} listId={listId} />
              ))}
            </div>
          </SortableContext>

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
      )}
    </div>
  );
};

export default LaterListTodoList;
