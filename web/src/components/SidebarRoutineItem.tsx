import React, { useState, useRef, useEffect, type KeyboardEvent } from 'react';
import { Pencil, Trash2, Play } from 'lucide-react';
import type { Routine } from '../types';
import { useRoutines } from '../context/RoutineContext';

interface SidebarRoutineItemProps {
  routine: Routine;
  isSelected: boolean;
  hasActiveExecution: boolean;
  onSelect: () => void;
}

const SidebarRoutineItem: React.FC<SidebarRoutineItemProps> = ({
  routine,
  isSelected,
  hasActiveExecution,
  onSelect,
}) => {
  const { updateRoutineName, deleteRoutine } = useRoutines();
  const [isEditing, setIsEditing] = useState(false);
  const [editName, setEditName] = useState(routine.name);
  const [isLoading, setIsLoading] = useState(false);
  const [isConfirmingDelete, setIsConfirmingDelete] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isEditing && inputRef.current) {
      inputRef.current.focus();
      inputRef.current.select();
    }
  }, [isEditing]);

  useEffect(() => {
    // Reset confirm delete after timeout
    if (isConfirmingDelete) {
      const timeout = setTimeout(() => setIsConfirmingDelete(false), 3000);
      return () => clearTimeout(timeout);
    }
  }, [isConfirmingDelete]);

  const handleEdit = (e: React.MouseEvent) => {
    e.stopPropagation();
    setEditName(routine.name);
    setIsEditing(true);
  };

  const handleSaveEdit = async () => {
    if (editName.trim() === '') {
      setEditName(routine.name);
      setIsEditing(false);
      return;
    }

    if (editName === routine.name) {
      setIsEditing(false);
      return;
    }

    setIsLoading(true);
    try {
      await updateRoutineName(routine.id, editName);
      setIsEditing(false);
    } catch (err) {
      console.error('Failed to update routine name:', err);
      setEditName(routine.name);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCancelEdit = () => {
    setEditName(routine.name);
    setIsEditing(false);
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      handleSaveEdit();
    } else if (e.key === 'Escape') {
      handleCancelEdit();
    }
  };

  const handleDelete = async (e: React.MouseEvent) => {
    e.stopPropagation();
    if (isConfirmingDelete) {
      setIsLoading(true);
      try {
        await deleteRoutine(routine.id);
      } catch (err) {
        console.error('Failed to delete routine:', err);
      } finally {
        setIsLoading(false);
        setIsConfirmingDelete(false);
      }
    } else {
      setIsConfirmingDelete(true);
    }
  };

  return (
    <div
      className={`sidebar-routine-item ${isSelected ? 'selected' : ''} ${isLoading ? 'loading' : ''}`}
      onClick={isEditing ? undefined : onSelect}
    >
      {isEditing ? (
        <input
          ref={inputRef}
          type="text"
          className="sidebar-routine-edit-input"
          value={editName}
          onChange={(e) => setEditName(e.target.value)}
          onBlur={handleSaveEdit}
          onKeyDown={handleKeyDown}
          onClick={(e) => e.stopPropagation()}
          disabled={isLoading}
        />
      ) : (
        <div className="sidebar-routine-name-container">
          <span className="sidebar-routine-name">{routine.name}</span>
          {hasActiveExecution && (
            <Play size={12} className="sidebar-routine-active-icon" fill="currentColor" />
          )}
        </div>
      )}

      <div className="sidebar-routine-actions">
        {!isEditing && (
          <button
            className="btn-sidebar-action"
            onClick={handleEdit}
            disabled={isLoading}
            title="Rename"
          >
            <Pencil size={14} />
          </button>
        )}
        <button
          className={`btn-sidebar-action btn-sidebar-delete ${isConfirmingDelete ? 'confirm' : ''}`}
          onClick={handleDelete}
          disabled={isLoading}
          title={isConfirmingDelete ? 'Click again to confirm' : 'Delete'}
        >
          <Trash2 size={14} />
        </button>
      </div>
    </div>
  );
};

export default SidebarRoutineItem;
