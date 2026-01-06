import React from 'react';
import { useDroppable } from '@dnd-kit/core';
import TodoList from './TodoList';
import { formatDate, formatDateForAPI } from '../utils/dateUtils';
import type { Todo } from '../types';

interface DroppableDayColumnProps {
  date: Date;
  todos: Todo[];
  activeId?: string | null;
  overId?: string | null;
}

const DroppableDayColumn: React.FC<DroppableDayColumnProps> = ({ date, todos, activeId, overId }) => {
  const { setNodeRef: setHeaderRef, isOver: isHeaderOver } = useDroppable({
    id: `day-${formatDateForAPI(date)}`,
    data: { date },
  });

  const { setNodeRef: setColumnRef, isOver: isColumnOver } = useDroppable({
    id: `day-bg-${formatDateForAPI(date)}`,
    data: { date },
  });

  // Helper to generate todo ID
  const getTodoId = (todo: Todo): string => {
    if (todo.id != null) {
      return `todo-${todo.id}`;
    }
    return `virtual-${todo.recurringTodoId}-${todo.instanceDate}`;
  };

  // Check if active todo is from a different day
  const activeTodoIsFromDifferentDay = activeId && !todos.some((t) => getTodoId(t) === activeId);

  // Check if overId is a todo in this column
  const overIdIsInThisColumn = overId && todos.some((t) => getTodoId(t) === overId);

  // Highlight entire column if:
  // 1. Hovering over header or background, OR
  // 2. Dragging from different day AND hovering over a todo in this column
  const isOver = isHeaderOver || isColumnOver || (activeTodoIsFromDifferentDay && overIdIsInThisColumn);

  return (
    <div
      ref={setColumnRef}
      className={`day-column ${isOver ? 'drop-target-active' : ''}`}
    >
      <div ref={setHeaderRef} className="day-header" style={{ minHeight: '50px' }}>
        <h3>{formatDate(date, 'EEE, MMM d')}</h3>
      </div>
      {/* Don't enable TodoList's own DndContext - parent handles it */}
      <TodoList
        todos={todos}
        date={date}
        enableDragContext={false}
        activeId={activeId}
        overId={overId}
        suppressPlaceholders={activeTodoIsFromDifferentDay}
      />
    </div>
  );
};

export default DroppableDayColumn;
