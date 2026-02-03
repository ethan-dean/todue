import React, { useState, useRef, useEffect } from 'react';
import { ChevronLeft, ChevronsLeft, ChevronRight, ChevronsRight, CalendarDays } from 'lucide-react';
import { useTodos } from '../context/TodoContext';
import { addDays, isToday, isSameDay, formatDate } from '../utils/dateUtils';
import { startOfMonth, endOfMonth, startOfWeek, endOfWeek, addMonths, eachDayOfInterval, isSameMonth } from 'date-fns';

const WEEKDAY_LABELS = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

function getCalendarDays(month: Date): Date[] {
  const start = startOfWeek(startOfMonth(month));
  const end = endOfWeek(endOfMonth(month));
  return eachDayOfInterval({ start, end });
}

const DateNavigator: React.FC = () => {
  const { selectedDate, viewMode, setViewMode, changeDate } = useTodos();
  const [isCalendarOpen, setIsCalendarOpen] = useState(false);
  const [viewingMonth, setViewingMonth] = useState(selectedDate);
  const calendarRef = useRef<HTMLDivElement>(null);

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
    setIsCalendarOpen((prev) => {
      if (!prev) {
        setViewingMonth(selectedDate);
      }
      return !prev;
    });
  };

  const handleDateSelect = (date: Date) => {
    changeDate(date);
    setIsCalendarOpen(false);
  };

  const handlePrevMonth = (e: React.MouseEvent) => {
    e.stopPropagation();
    setViewingMonth((prev) => addMonths(prev, -1));
  };

  const handleNextMonth = (e: React.MouseEvent) => {
    e.stopPropagation();
    setViewingMonth((prev) => addMonths(prev, 1));
  };

  const handleViewModeChange = (mode: 1 | 3 | 5 | 7) => {
    setViewMode(mode);
  };

  // Close on click outside
  useEffect(() => {
    if (!isCalendarOpen) return;

    const handleMouseDown = (e: MouseEvent) => {
      if (calendarRef.current && !calendarRef.current.contains(e.target as Node)) {
        setIsCalendarOpen(false);
      }
    };

    document.addEventListener('mousedown', handleMouseDown);
    return () => document.removeEventListener('mousedown', handleMouseDown);
  }, [isCalendarOpen]);

  // Close on Escape
  useEffect(() => {
    if (!isCalendarOpen) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setIsCalendarOpen(false);
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [isCalendarOpen]);

  const calendarDays = getCalendarDays(viewingMonth);
  const today = new Date();

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

      <div className="nav-group center-group" ref={calendarRef}>
        <button onClick={handleCalendarClick} className="btn-header-calendar" title="Pick a date">
          <CalendarDays size={18} />
        </button>

        {!isToday(selectedDate) && (
          <button onClick={handleToday} className="btn-header-today">
            Today
          </button>
        )}

        {isCalendarOpen && (
          <div className="calendar-picker">
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
              {calendarDays.map((day, i) => {
                const outside = !isSameMonth(day, viewingMonth);
                const isSelected = isSameDay(day, selectedDate);
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
