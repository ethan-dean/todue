import React, { useRef, useEffect } from 'react';
import { useTodos } from '../context/TodoContext';
import { addDays, formatDate, isToday } from '../utils/dateUtils';

const MobileDateCarousel: React.FC = () => {
  const { selectedDate, changeDate } = useTodos();
  const scrollContainerRef = useRef<HTMLDivElement>(null);

  // Generate array of dates (selected date +/- 30 days for scrolling)
  const dates = Array.from({ length: 61 }, (_, i) => addDays(selectedDate, i - 30));

  // Scroll to center the selected date
  useEffect(() => {
    if (scrollContainerRef.current) {
      const container = scrollContainerRef.current;
      const selectedElement = container.querySelector('.date-item.selected') as HTMLElement;

      if (selectedElement) {
        const containerWidth = container.offsetWidth;
        const itemLeft = selectedElement.offsetLeft;
        const itemWidth = selectedElement.offsetWidth;

        // Scroll to center the selected item
        container.scrollTo({
          left: itemLeft - containerWidth / 2 + itemWidth / 2,
          behavior: 'smooth',
        });
      }
    }
  }, [selectedDate]);

  const handleDateClick = (date: Date) => {
    changeDate(date);
  };

  const getDayOfWeek = (date: Date): string => {
    return formatDate(date, 'EEE'); // Mon, Tue, etc.
  };

  const getDayOfMonth = (date: Date): number => {
    return date.getDate();
  };

  const isSameDay = (date1: Date, date2: Date): boolean => {
    return (
      date1.getFullYear() === date2.getFullYear() &&
      date1.getMonth() === date2.getMonth() &&
      date1.getDate() === date2.getDate()
    );
  };

  return (
    <div className="mobile-date-carousel">
      <div className="carousel-header">
        <h2 className="carousel-title">{formatDate(selectedDate, 'MMMM yyyy')}</h2>
        {!isToday(selectedDate) && (
          <button onClick={() => changeDate(new Date())} className="btn-today-mobile">
            Today
          </button>
        )}
      </div>
      <div className="carousel-scroll-container" ref={scrollContainerRef}>
        {dates.map((date, index) => {
          const isSelected = isSameDay(date, selectedDate);
          const isTodayDate = isToday(date);

          return (
            <button
              key={index}
              className={`date-item ${isSelected ? 'selected' : ''} ${isTodayDate ? 'today' : ''}`}
              onClick={() => handleDateClick(date)}
            >
              <div className="date-day">{getDayOfWeek(date)}</div>
              <div className="date-number">{getDayOfMonth(date)}</div>
            </button>
          );
        })}
      </div>
    </div>
  );
};

export default MobileDateCarousel;
