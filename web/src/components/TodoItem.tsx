import React, { useState, useRef, useEffect, type KeyboardEvent } from 'react';
import { Pencil, Calendar, Trash2, Repeat } from 'lucide-react';
import type { Todo } from '../types';
import { useTodos } from '../context/TodoContext';

interface TodoItemProps {
  todo: Todo;
  onDelete: (deleteAllFuture?: boolean) => void;
}

const TodoItem: React.FC<TodoItemProps> = ({ todo, onDelete }) => {
  const { updateTodoText, completeTodo, uncompleteTodo, moveTodo } = useTodos();
  const [isEditing, setIsEditing] = useState(false);
  const [editText, setEditText] = useState(todo.text);
  const [isLoading, setIsLoading] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const dateInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isEditing && inputRef.current) {
      inputRef.current.focus();
      inputRef.current.select();
    }
  }, [isEditing]);

  const handleToggleComplete = async () => {
    if (isLoading) return;

    setIsLoading(true);
    try {
      if (todo.isCompleted) {
        // Uncomplete the todo
        await uncompleteTodo(
          todo.id!,
          todo.isVirtual,
          todo.recurringTodoId,
          todo.instanceDate,
          todo.assignedDate
        );
      } else {
        // Complete the todo
        await completeTodo(
          todo.id!,
          todo.isVirtual,
          todo.recurringTodoId,
          todo.instanceDate,
          todo.assignedDate
        );
      }
    } catch (err) {
      console.error('Failed to toggle todo completion:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleEdit = () => {
    if (todo.isCompleted) return;
    setEditText(todo.text);
    setIsEditing(true);
  };

  const handleSaveEdit = async () => {
    if (editText.trim() === '') {
      setEditText(todo.text);
      setIsEditing(false);
      return;
    }

    if (editText === todo.text) {
      setIsEditing(false);
      return;
    }

    setIsLoading(true);
    try {
      await updateTodoText(
        todo.id!,
        editText,
        todo.isVirtual,
        todo.recurringTodoId,
        todo.instanceDate,
        todo.assignedDate
      );
      setIsEditing(false);
    } catch (err) {
      console.error('Failed to update todo:', err);
      setEditText(todo.text);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCancelEdit = () => {
    setEditText(todo.text);
    setIsEditing(false);
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      handleSaveEdit();
    } else if (e.key === 'Escape') {
      handleCancelEdit();
    }
  };

  const handleDeleteClick = () => {
    if (todo.recurringTodoId) {
      // Show confirmation for recurring todos
      const deleteAll = window.confirm(
        'This is a recurring todo. Delete all future instances? (Click OK for yes, Cancel for just this one)'
      );
      onDelete(deleteAll);
    } else {
      onDelete();
    }
  };

  const handleMoveClick = () => {
    if (isLoading) return;
    dateInputRef.current?.showPicker();
  };

  const handleDateChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const dateStr = e.target.value;
    if (!dateStr) return;

    setIsLoading(true);
    try {
      // Parse YYYY-MM-DD to Date object
      const [year, month, day] = dateStr.split('-').map(Number);
      const newDate = new Date(year, month - 1, day);
      await moveTodo(todo, newDate);
    } catch (err) {
      console.error('Failed to move todo:', err);
    } finally {
      setIsLoading(false);
      // Reset date input for next use
      if (dateInputRef.current) {
        dateInputRef.current.value = '';
      }
    }
  };

  const getClassName = () => {
    const classes = ['todo-item'];
    if (todo.isCompleted) classes.push('completed');
    if (todo.isRolledOver) classes.push('rolled-over');
    if (todo.isVirtual) classes.push('virtual');
    if (isLoading) classes.push('loading');
    return classes.join(' ');
  };

  return (
    <div className={getClassName()}>
      <div className="todo-checkbox">
        <input
          type="checkbox"
          checked={todo.isCompleted}
          onChange={handleToggleComplete}
          disabled={isLoading}
        />
      </div>

      {isEditing ? (
        <input
          ref={inputRef}
          type="text"
          className="todo-edit-input"
          value={editText}
          onChange={(e) => setEditText(e.target.value)}
          onBlur={handleSaveEdit}
          onKeyDown={handleKeyDown}
          disabled={isLoading}
        />
      ) : (
        <div className="todo-text" onDoubleClick={handleEdit}>
          {todo.text}
          {todo.recurringTodoId && <span className="recurring-indicator"><Repeat size={14} /></span>}
        </div>
      )}

      <div className="todo-actions">
        {!isEditing && !todo.isCompleted && (
          <button
            className="btn-edit"
            onClick={handleEdit}
            disabled={isLoading}
            title="Edit"
          >
            <Pencil size={16} />
          </button>
        )}
        <button
          className="btn-move"
          onClick={handleMoveClick}
          disabled={isLoading}
          title="Move to date"
        >
          <Calendar size={16} />
        </button>
        <button
          className="btn-delete"
          onClick={handleDeleteClick}
          disabled={isLoading}
          title="Delete"
        >
          <Trash2 size={16} />
        </button>
      </div>

      {/* Hidden date picker */}
      <input
        ref={dateInputRef}
        type="date"
        onChange={handleDateChange}
        style={{ position: 'absolute', opacity: 0, pointerEvents: 'none' }}
      />
    </div>
  );
};

export default TodoItem;
