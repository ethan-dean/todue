import React, { useState, useRef, useEffect, type KeyboardEvent } from 'react';
import { Pencil, Trash2 } from 'lucide-react';
import type { LaterListTodo } from '../types';
import { useLaterLists } from '../context/LaterListContext';

interface LaterListTodoItemProps {
  todo: LaterListTodo;
  listId: number;
}

const LaterListTodoItem: React.FC<LaterListTodoItemProps> = ({ todo, listId }) => {
  const { updateTodoText, completeTodo, uncompleteTodo, deleteTodo } = useLaterLists();
  const [isEditing, setIsEditing] = useState(false);
  const [editText, setEditText] = useState(todo.text);
  const [isLoading, setIsLoading] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

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
        await uncompleteTodo(listId, todo.id);
      } else {
        await completeTodo(listId, todo.id);
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
      await updateTodoText(listId, todo.id, editText);
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

  const handleDelete = async () => {
    setIsLoading(true);
    try {
      await deleteTodo(listId, todo.id);
    } catch (err) {
      console.error('Failed to delete todo:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const getClassName = () => {
    const classes = ['todo-item', 'later-list-todo-item'];
    if (todo.isCompleted) classes.push('completed');
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
          className="btn-delete"
          onClick={handleDelete}
          disabled={isLoading}
          title="Delete"
        >
          <Trash2 size={16} />
        </button>
      </div>
    </div>
  );
};

export default LaterListTodoItem;
