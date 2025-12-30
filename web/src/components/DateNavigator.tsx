import React from 'react';
import { useTodos } from '../context/TodoContext';
import { formatDate, addDays, isToday } from '../utils/dateUtils';

const DateNavigator: React.FC = () => {
  const { selectedDate, viewMode, setViewMode, changeDate } = useTodos();

  const handlePrevDay = () => {
    changeDate(addDays(selectedDate, -1));
  };

  const handleNextDay = () => {
    changeDate(addDays(selectedDate, 1));
  };

  const handleToday = () => {
    changeDate(new Date());
  };

  const handleViewModeChange = (mode: 1 | 3 | 5 | 7) => {
    setViewMode(mode);
  };

  const getViewModeLabel = () => {
    if (viewMode === 1) {
      return formatDate(selectedDate, 'EEEE, MMMM d, yyyy');
    } else {
      const startDate = addDays(selectedDate, -Math.floor(viewMode / 2));
      const endDate = addDays(selectedDate, Math.floor(viewMode / 2));
      return `${formatDate(startDate, 'MMM d')} - ${formatDate(endDate, 'MMM d, yyyy')}`;
    }
  };

  return (
    <div className="date-navigator">
      <div className="date-controls">
        <button onClick={handlePrevDay} className="btn-nav" title="Previous Day">
          ◀
        </button>

        <div className="date-display">
          <span className="date-label">{getViewModeLabel()}</span>
          {!isToday(selectedDate) && (
            <button onClick={handleToday} className="btn-today">
              Today
            </button>
          )}
        </div>

        <button onClick={handleNextDay} className="btn-nav" title="Next Day">
          ▶
        </button>
      </div>

      <div className="view-mode-selector">
        <span className="view-mode-label">View:</span>
        <button
          onClick={() => handleViewModeChange(1)}
          className={`btn-view-mode ${viewMode === 1 ? 'active' : ''}`}
        >
          1 Day
        </button>
        <button
          onClick={() => handleViewModeChange(3)}
          className={`btn-view-mode ${viewMode === 3 ? 'active' : ''}`}
        >
          3 Days
        </button>
        <button
          onClick={() => handleViewModeChange(5)}
          className={`btn-view-mode ${viewMode === 5 ? 'active' : ''}`}
        >
          5 Days
        </button>
        <button
          onClick={() => handleViewModeChange(7)}
          className={`btn-view-mode ${viewMode === 7 ? 'active' : ''}`}
        >
          7 Days
        </button>
      </div>
    </div>
  );
};

export default DateNavigator;
