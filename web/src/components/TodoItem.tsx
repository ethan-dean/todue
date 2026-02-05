import React, { useState, useRef, useEffect, type KeyboardEvent } from 'react';
import { Pencil, Calendar, Trash2, Repeat, ChevronLeft, ChevronRight } from 'lucide-react';
import { startOfMonth, endOfMonth, startOfWeek, endOfWeek, addMonths, eachDayOfInterval, isSameMonth, isSameDay } from 'date-fns';
import type { Todo } from '../types';
import { useTodos } from '../context/TodoContext';
import { formatDate } from '../utils/dateUtils';

const WEEKDAY_LABELS = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

function getCalendarDays(month: Date): Date[] {
  const start = startOfWeek(startOfMonth(month));
  const end = endOfWeek(endOfMonth(month));
  return eachDayOfInterval({ start, end });
}

interface TodoItemProps {
  todo: Todo;
  onDelete: (deleteAllFuture?: boolean) => void;
}

const TodoItem: React.FC<TodoItemProps> = ({ todo, onDelete }) => {
  const { updateTodoText, completeTodo, uncompleteTodo, moveTodo } = useTodos();
  const [isEditing, setIsEditing] = useState(false);
  const [editText, setEditText] = useState(todo.text);
  const [isLoading, setIsLoading] = useState(false);
  const [isDatePickerOpen, setIsDatePickerOpen] = useState(false);
  const [viewingMonth, setViewingMonth] = useState(new Date());
  const inputRef = useRef<HTMLInputElement>(null);
  const datePickerRef = useRef<HTMLDivElement>(null);

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
    setIsDatePickerOpen((prev) => {
      if (!prev) {
        // Initialize to the todo's current date
        const [year, month, day] = todo.assignedDate.split('-').map(Number);
        setViewingMonth(new Date(year, month - 1, day));
      }
      return !prev;
    });
  };

  const handleDateSelect = async (date: Date) => {
    setIsDatePickerOpen(false);
    setIsLoading(true);
    try {
      await moveTodo(todo, date);
    } catch (err) {
      console.error('Failed to move todo:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const handlePrevMonth = (e: React.MouseEvent) => {
    e.stopPropagation();
    setViewingMonth((prev) => addMonths(prev, -1));
  };

  const handleNextMonth = (e: React.MouseEvent) => {
    e.stopPropagation();
    setViewingMonth((prev) => addMonths(prev, 1));
  };

  // Close date picker on click outside
  useEffect(() => {
    if (!isDatePickerOpen) return;

    const handleMouseDown = (e: MouseEvent) => {
      if (datePickerRef.current && !datePickerRef.current.contains(e.target as Node)) {
        setIsDatePickerOpen(false);
      }
    };

    document.addEventListener('mousedown', handleMouseDown);
    return () => document.removeEventListener('mousedown', handleMouseDown);
  }, [isDatePickerOpen]);

  // Close date picker on Escape
  useEffect(() => {
    if (!isDatePickerOpen) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setIsDatePickerOpen(false);
      }
    };

    document.addEventListener('keydown', handleKeyDown as unknown as EventListener);
    return () => document.removeEventListener('keydown', handleKeyDown as unknown as EventListener);
  }, [isDatePickerOpen]);

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

      {/* Custom date picker popover */}
      {isDatePickerOpen && (
        <div ref={datePickerRef} className="todo-date-picker">
          <div className="calendar-header">
            <button className="calendar-nav-btn" onClick={handlePrevMonth} title="Previous month">
              <ChevronLeft size={16} />
            </button>
            <span className="calendar-month-label">
              {formatDate(viewingMonth, 'MMMM yyyy')}
            </span>
            <button className="calendar-nav-btn" onClick={handleNextMonth} title="Next month">
              <ChevronRight size={16} />
            </button>
          </div>
          <div className="calendar-weekdays">
            {WEEKDAY_LABELS.map((label, i) => (
              <span key={i} className="calendar-weekday">{label}</span>
            ))}
          </div>
          <div className="calendar-grid">
            {getCalendarDays(viewingMonth).map((day, i) => {
              const outside = !isSameMonth(day, viewingMonth);
              const today = new Date();
              const [year, month, dayNum] = todo.assignedDate.split('-').map(Number);
              const currentTodoDate = new Date(year, month - 1, dayNum);
              const isSelected = isSameDay(day, currentTodoDate);
              const isTodayDate = isSameDay(day, today);

              let className = 'calendar-day';
              if (outside) className += ' calendar-day-outside';
              if (isTodayDate) className += ' calendar-day-today';
              if (isSelected) className += ' calendar-day-selected';

              return (
                <button
                  key={i}
                  className={className}
                  onClick={() => handleDateSelect(day)}
                >
                  {day.getDate()}
                </button>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
};

export default TodoItem;
