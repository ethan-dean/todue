import React, { useRef } from 'react';
import { ChevronLeft, ChevronsLeft, ChevronRight, ChevronsRight, CalendarDays } from 'lucide-react';
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
    <div className="header-date-navigator">
      <div className="nav-group">
        <button onClick={handlePrevRange} className="btn-header-nav" title={`Previous ${viewMode} Day${viewMode > 1 ? 's' : ''}`}>
          <ChevronsLeft size={20} />
        </button>
        <button onClick={handlePrevDay} className="btn-header-nav" title="Previous Day">
          <ChevronLeft size={20} />
        </button>
      </div>

      <div className="nav-group center-group">
        <button onClick={handleCalendarClick} className="btn-header-calendar" title="Pick a date">
          <CalendarDays size={18} />
        </button>
        
        {!isToday(selectedDate) && (
          <button onClick={handleToday} className="btn-header-today">
            Today
          </button>
        )}
        
        <input
          ref={dateInputRef}
          type="date"
          value={formatDateForInput(selectedDate)}
          onChange={handleDatePickerChange}
          style={{ position: 'absolute', opacity: 0, pointerEvents: 'none', top: 0, left: 0 }}
        />
      </div>

      <div className="nav-group">
        <button onClick={handleNextDay} className="btn-header-nav" title="Next Day">
          <ChevronRight size={20} />
        </button>
        <button onClick={handleNextRange} className="btn-header-nav" title={`Next ${viewMode} Day${viewMode > 1 ? 's' : ''}`}>
          <ChevronsRight size={20} />
        </button>
      </div>

      <div className="header-view-mode">
        {[1, 3, 5, 7].map((mode) => (
          <button
            key={mode}
            onClick={() => handleViewModeChange(mode as 1 | 3 | 5 | 7)}
            className={`btn-header-view ${viewMode === mode ? 'active' : ''}`}
          >
            {mode}
          </button>
        ))}
      </div>
    </div>
  );
};

export default DateNavigator;
