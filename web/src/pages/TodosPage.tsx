import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { useTodos } from '../context/TodoContext';
import { useTheme } from '../context/ThemeContext';
import DateNavigator from '../components/DateNavigator';
import MobileDateCarousel from '../components/MobileDateCarousel';
import TodoList from '../components/TodoList';
import { formatDateForAPI, formatDate, getDateRange } from '../utils/dateUtils';

const TodosPage: React.FC = () => {
  const { user, logout } = useAuth();
  const { todos, selectedDate, viewMode, setViewMode, isLoading, error } = useTodos();
  const { theme, toggleTheme } = useTheme();

  // Detect mobile vs desktop
  const [isMobile, setIsMobile] = useState(window.innerWidth < 768);

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

  const handleLogout = () => {
    logout();
  };

  const renderSingleDayView = () => {
    const dateStr = formatDateForAPI(selectedDate);
    const todosForDate = todos.get(dateStr) || [];

    return (
      <div className="single-day-view">
        <div className="day-header">
          <h3>{formatDate(selectedDate, 'EEE, MMM d')}</h3>
        </div>
        <TodoList todos={todosForDate} date={selectedDate} />
      </div>
    );
  };

  const renderMultiDayView = () => {
    const dates = getDateRange(selectedDate, viewMode);

    return (
      <div className="multi-day-view">
        {dates.map((date) => {
          const dateStr = formatDateForAPI(date);
          const todosForDate = todos.get(dateStr) || [];

          return (
            <div key={dateStr} className="day-column">
              <div className="day-header">
                <h3>{formatDate(date, 'EEE, MMM d')}</h3>
              </div>
              <TodoList todos={todosForDate} date={date} />
            </div>
          );
        })}
      </div>
    );
  };

  return (
    <div className="todos-page">
      <header className="app-header">
        <div className="header-content">
          <h1>Todue</h1>
          <div className="user-info">
            <button
              onClick={toggleTheme}
              className="btn-theme-toggle"
              title={`Switch to ${theme === 'light' ? 'dark' : 'light'} mode`}
            >
              {theme === 'light' ? '🌙' : '☀️'}
            </button>
            <span className="user-email">{user?.email}</span>
            <button onClick={handleLogout} className="btn-logout">
              Logout
            </button>
          </div>
        </div>
      </header>

      <main className="app-main">
        {isMobile ? <MobileDateCarousel /> : <DateNavigator />}

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
