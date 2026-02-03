import React, { useState, useEffect } from 'react';
import { Trash2, Play } from 'lucide-react';
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
  const { deleteRoutine } = useRoutines();
  const [isLoading, setIsLoading] = useState(false);
  const [isConfirmingDelete, setIsConfirmingDelete] = useState(false);

  useEffect(() => {
    // Reset confirm delete after timeout
    if (isConfirmingDelete) {
      const timeout = setTimeout(() => setIsConfirmingDelete(false), 3000);
      return () => clearTimeout(timeout);
    }
  }, [isConfirmingDelete]);

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
      onClick={onSelect}
    >
      <div className="sidebar-routine-name-container">
        <span className="sidebar-routine-name">{routine.name}</span>
        {hasActiveExecution && (
          <Play size={12} className="sidebar-routine-active-icon" fill="currentColor" />
        )}
      </div>

      <div className="sidebar-routine-actions">
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
