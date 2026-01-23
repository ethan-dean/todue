import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { User } from 'lucide-react';
import {
  DndContext,
  closestCorners,
  PointerSensor,
  useSensor,
  useSensors,
  DragOverlay,
  type DragEndEvent,
  type DragStartEvent,
  type DragOverEvent,
} from '@dnd-kit/core';
import { useTodos } from '../context/TodoContext';
import DateNavigator from '../components/DateNavigator';
import MobileDateCarousel from '../components/MobileDateCarousel';
import TodoList from '../components/TodoList';
import DroppableDayColumn from '../components/DroppableDayColumn';
import { formatDateForAPI, formatDate, getDateRange } from '../utils/dateUtils';
import type { Todo } from '../types';

const TodosPage: React.FC = () => {
  const { todos, selectedDate, viewMode, setViewMode, isLoading, error, moveTodo, updateTodoPosition } = useTodos();
  const navigate = useNavigate();

  // Detect mobile vs desktop
  const [isMobile, setIsMobile] = useState(window.innerWidth < 768);

  // Track active drag for multi-day view
  const [activeId, setActiveId] = useState<string | null>(null);
  const [overId, setOverId] = useState<string | null>(null);

  // Drag sensor for multi-day drag-drop
  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 8, // Requires 8px movement before drag activates
      },
    })
  );

  useEffect(() => {
    const handleResize = () => {
      const mobile = window.innerWidth < 768;
      setIsMobile(mobile);

      // Force single day view on mobile
      if (mobile && viewMode !== 1) {
        setViewMode(1);
      }
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [viewMode, setViewMode]);

  const handleSettingsClick = () => {
    navigate('/settings');
  };

  const renderSingleDayView = () => {
    const dateStr = formatDateForAPI(selectedDate);
    const todosForDate = todos.get(dateStr) || [];

    return (
      <div className="single-day-view">
        <div className="day-header">
          <h3>{formatDate(selectedDate, 'EEE, MMM d')}</h3>
        </div>
        <TodoList todos={todosForDate} date={selectedDate} enableDragContext={true} />
      </div>
    );
  };

  const handleCrossDayDragStart = (event: DragStartEvent) => {
    setActiveId(event.active.id as string);
  };

  const handleCrossDayDragOver = (event: DragOverEvent) => {
    setOverId(event.over?.id ? String(event.over.id) : null);
  };

  const handleCrossDayDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;

    setActiveId(null);
    setOverId(null);

    if (!over || active.id === over.id) return;

    const overIdStr = String(over.id);

    // Find the todo being dragged from all dates
    let sourceTodo: Todo | null = null;
    for (const [, todoList] of todos) {
      const found = todoList.find((t) => {
        const todoId = t.id != null ? `todo-${t.id}` : `virtual-${t.recurringTodoId}-${t.instanceDate}`;
        return todoId === active.id;
      });
      if (found) {
        sourceTodo = found;
        break;
      }
    }

    if (!sourceTodo) return;

    // Check if dropped on a day column (cross-day move)
    if (overIdStr.startsWith('day-') || overIdStr.startsWith('day-bg-')) {
      const targetDateStr = overIdStr.replace('day-', '').replace('day-bg-', '');

      // Check if we're moving to a different date
      if (sourceTodo.assignedDate === targetDateStr) return;

      // Parse target date string (YYYY-MM-DD) to Date object
      const [year, month, day] = targetDateStr.split('-').map(Number);
      const targetDate = new Date(year, month - 1, day);

      // Move the todo to different date
      moveTodo(sourceTodo, targetDate);
    } else {
      // Dropped on another todo (within-day reordering)
      // Find the target todo
      let targetTodo: Todo | null = null;
      for (const [, todoList] of todos) {
        const found = todoList.find((t) => {
          const todoId = t.id != null ? `todo-${t.id}` : `virtual-${t.recurringTodoId}-${t.instanceDate}`;
          return todoId === over.id;
        });
        if (found) {
          targetTodo = found;
          break;
        }
      }

      if (!targetTodo) return;

      // Check if cross-day move (dropped on todo in different day)
      if (sourceTodo.assignedDate !== targetTodo.assignedDate) {
        // Parse target date and move to that day
        const [year, month, day] = targetTodo.assignedDate.split('-').map(Number);
        const targetDate = new Date(year, month - 1, day);
        moveTodo(sourceTodo, targetDate);
        return;
      }

      // Get todos for this date
      const dateStr = sourceTodo.assignedDate;
      const dateList = todos.get(dateStr) || [];
      const sortedList = [...dateList].sort((a, b) => a.position - b.position);

      const oldIndex = sortedList.findIndex((t) => {
        const todoId = t.id != null ? `todo-${t.id}` : `virtual-${t.recurringTodoId}-${t.instanceDate}`;
        return todoId === active.id;
      });
      const newIndex = sortedList.findIndex((t) => {
        const todoId = t.id != null ? `todo-${t.id}` : `virtual-${t.recurringTodoId}-${t.instanceDate}`;
        return todoId === over.id;
      });

      if (oldIndex === -1 || newIndex === -1) return;

      // Call updateTodoPosition with the new index
      updateTodoPosition(
        sourceTodo.id!,
        newIndex,
        sourceTodo.isVirtual,
        sourceTodo.recurringTodoId,
        sourceTodo.instanceDate,
        sourceTodo.assignedDate
      );
    }
  };

  const renderMultiDayView = () => {
    const dates = getDateRange(selectedDate, viewMode);

    // Find the active todo for drag overlay
    let activeTodo: Todo | null = null;
    if (activeId) {
      for (const [, todoList] of todos) {
        const found = todoList.find((t) => {
          const todoId = t.id != null ? `todo-${t.id}` : `virtual-${t.recurringTodoId}-${t.instanceDate}`;
          return todoId === activeId;
        });
        if (found) {
          activeTodo = found;
          break;
        }
      }
    }

    return (
      <DndContext
        sensors={sensors}
        collisionDetection={closestCorners}
        onDragStart={handleCrossDayDragStart}
        onDragOver={handleCrossDayDragOver}
        onDragEnd={handleCrossDayDragEnd}
        onDragCancel={() => { setActiveId(null); setOverId(null); }}
      >
        <div className="multi-day-view">
          {dates.map((date) => {
            const dateStr = formatDateForAPI(date);
            const todosForDate = todos.get(dateStr) || [];

            return (
              <DroppableDayColumn
                key={dateStr}
                date={date}
                todos={todosForDate}
                activeId={activeId}
                overId={overId}
              />
            );
          })}
        </div>

        {/* Drag overlay for cross-day dragging */}
        <DragOverlay>
          {activeTodo ? (
            <div className="todo-item drag-preview" style={{ cursor: 'grabbing' }}>
              <div className="todo-checkbox">
                <input type="checkbox" checked={activeTodo.isCompleted} readOnly />
              </div>
              <div className="todo-text">
                {activeTodo.text}
                {activeTodo.recurringTodoId && <span className="recurring-indicator">🔄</span>}
              </div>
              <div className="todo-actions"></div>
            </div>
          ) : null}
        </DragOverlay>
      </DndContext>
    );
  };

  return (
    <div className="todos-page">
      <header className="app-header">
        <div className="header-content">
          <h1>Todue</h1>
          <div className="header-right">
            {!isMobile && <DateNavigator />}
            <div className="header-tabs">
              <button className="header-tab active">Now</button>
              <button
                className="header-tab"
                onClick={() => navigate('/later')}
              >
                Later
              </button>
              <button
                className="header-tab"
                onClick={() => navigate('/routines')}
              >
                Routines
              </button>
            </div>
            <div className="user-info">
              <button
                onClick={handleSettingsClick}
                className="btn-account"
                title="Settings"
              >
                <User size={20} color="#ffffff" />
              </button>
            </div>
          </div>
        </div>
      </header>

      <main className="app-main">
        {isMobile && <MobileDateCarousel />}

        {error && (
          <div className="error-banner" role="alert">
            {error}
          </div>
        )}

        {isLoading ? (
          <div className="loading-container">
            <div className="loading-spinner">Loading todos...</div>
          </div>
        ) : (
          <div className="todos-container">
            {viewMode === 1 ? renderSingleDayView() : renderMultiDayView()}
          </div>
        )}
      </main>
    </div>
  );
};

export default TodosPage;
