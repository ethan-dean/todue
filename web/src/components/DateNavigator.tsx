import React, { useRef } from 'react';
import { useTodos } from '../context/TodoContext';
import { addDays, isToday } from '../utils/dateUtils';

const DateNavigator: React.FC = () => {
  const { selectedDate, viewMode, setViewMode, changeDate } = useTodos();
  const dateInputRef = useRef<HTMLInputElement>(null);

  const handlePrevDay = () => {
    changeDate(addDays(selectedDate, -1));
  };

  const handleNextDay = () => {
    changeDate(addDays(selectedDate, 1));
  };

  const handlePrevRange = () => {
    changeDate(addDays(selectedDate, -viewMode));
  };

  const handleNextRange = () => {
    changeDate(addDays(selectedDate, viewMode));
  };

  const handleToday = () => {
    changeDate(new Date());
  };

  const handleCalendarClick = () => {
    dateInputRef.current?.showPicker();
  };

  const handleDatePickerChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const dateStr = e.target.value;
    if (dateStr) {
      // Parse YYYY-MM-DD to Date object
      const [year, month, day] = dateStr.split('-').map(Number);
      const newDate = new Date(year, month - 1, day);
      changeDate(newDate);
    }
  };

  const formatDateForInput = (date: Date): string => {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  };

  const handleViewModeChange = (mode: 1 | 3 | 5 | 7) => {
    setViewMode(mode);
  };

  return (
    <div className="date-navigator">
      <div className="date-controls">
        <button onClick={handlePrevRange} className="btn-nav" title={`Previous ${viewMode} Day${viewMode > 1 ? 's' : ''}`}>
          ◀◀
        </button>
        <button onClick={handlePrevDay} className="btn-nav" title="Previous Day">
          ◀
        </button>

        <div className="date-display">
          <div className="date-actions">
            <button onClick={handleCalendarClick} className="btn-calendar" title="Pick a date">
              📅
            </button>
            {!isToday(selectedDate) && (
              <button onClick={handleToday} className="btn-today">
                Today
              </button>
            )}
          </div>
          <input
            ref={dateInputRef}
            type="date"
            value={formatDateForInput(selectedDate)}
            onChange={handleDatePickerChange}
            style={{ position: 'absolute', opacity: 0, pointerEvents: 'none' }}
          />
        </div>

        <button onClick={handleNextDay} className="btn-nav" title="Next Day">
          ▶
        </button>
        <button onClick={handleNextRange} className="btn-nav" title={`Next ${viewMode} Day${viewMode > 1 ? 's' : ''}`}>
          ▶▶
        </button>
      </div>

      <div className="view-mode-selector">
        <button
          onClick={() => handleViewModeChange(1)}
          className={`btn-view-mode ${viewMode === 1 ? 'active' : ''}`}
        >
          1
        </button>
        <button
          onClick={() => handleViewModeChange(3)}
          className={`btn-view-mode ${viewMode === 3 ? 'active' : ''}`}
        >
          3
        </button>
        <button
          onClick={() => handleViewModeChange(5)}
          className={`btn-view-mode ${viewMode === 5 ? 'active' : ''}`}
        >
          5
        </button>
        <button
          onClick={() => handleViewModeChange(7)}
          className={`btn-view-mode ${viewMode === 7 ? 'active' : ''}`}
        >
          7
        </button>
      </div>
    </div>
  );
};

export default DateNavigator;
