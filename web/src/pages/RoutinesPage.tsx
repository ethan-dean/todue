import React, { useState, useEffect, useMemo } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
  User,
  Plus,
  Menu,
  X,
  Play,
  BarChart2,
  GripVertical,
  Trash2,
  Clock,
  Edit2,
  Check,
  ChevronLeft,
  ChevronRight,
  Flame,
  Award,
  TrendingUp,
} from 'lucide-react';
import { useRoutines } from '../context/RoutineContext';
import type { ScheduleEntry } from '../types';
import SidebarRoutineItem from '../components/SidebarRoutineItem';
import CreateRoutineModal from '../components/CreateRoutineModal';
import ScheduleRoutineModal from '../components/ScheduleRoutineModal';

const DAYS_OF_WEEK = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const LAST_VIEWED_ROUTINE_KEY = 'todue_last_viewed_routine';

const RoutinesPage: React.FC = () => {
  const { routineId: urlRoutineId } = useParams<{ routineId: string }>();
  const navigate = useNavigate();
  const {
    routines,
    routineDetails,
    analytics,
    activeExecutions,
    isLoading,
    error,
    createRoutine,
    loadRoutineDetail,
    loadAnalytics,
    updateRoutineName,
    createStep,
    updateStepText,
    updateStepPosition,
    deleteStep,
    setSchedules,
    startRoutine,
  } = useRoutines();

  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [showAnalytics, setShowAnalytics] = useState(false);
  const [isStarting, setIsStarting] = useState(false);

  // Detail editing state
  const [isEditingName, setIsEditingName] = useState(false);
  const [editedName, setEditedName] = useState('');
  const [newStepText, setNewStepText] = useState('');
  const [editingStepId, setEditingStepId] = useState<number | null>(null);
  const [editedStepText, setEditedStepText] = useState('');
  const [deletingStepId, setDeletingStepId] = useState<number | null>(null);
  const [isScheduleModalOpen, setIsScheduleModalOpen] = useState(false);
  const [draggedStepId, setDraggedStepId] = useState<number | null>(null);

  // Analytics state
  const [viewDate, setViewDate] = useState(() => new Date());

  // Get sorted routines
  const sortedRoutines = useMemo(
    () => [...routines].sort((a, b) => a.name.localeCompare(b.name)),
    [routines]
  );

  // Derive the selected routine ID from URL or fallbacks
  const selectedRoutineId = useMemo((): number | null => {
    // Priority 1: URL param if valid
    if (urlRoutineId) {
      const numericId = parseInt(urlRoutineId, 10);
      if (routines.some((r) => r.id === numericId)) {
        return numericId;
      }
    }

    // Priority 2: localStorage if valid
    const savedRoutineId = localStorage.getItem(LAST_VIEWED_ROUTINE_KEY);
    if (savedRoutineId) {
      const numericId = parseInt(savedRoutineId, 10);
      if (routines.some((r) => r.id === numericId)) {
        return numericId;
      }
    }

    // Priority 3: First routine alphabetically
    if (sortedRoutines.length > 0) {
      return sortedRoutines[0].id;
    }

    // Priority 4: No routines
    return null;
  }, [urlRoutineId, routines, sortedRoutines]);

  const routineDetail = selectedRoutineId ? routineDetails.get(selectedRoutineId) : null;
  const routineAnalytics = selectedRoutineId ? analytics.get(selectedRoutineId) : null;
  const hasActiveExecution = selectedRoutineId ? activeExecutions.has(selectedRoutineId) : false;

  // Calculate date range for the current month view (analytics)
  const { startDate, endDate, monthLabel } = useMemo(() => {
    const year = viewDate.getFullYear();
    const month = viewDate.getMonth();
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);

    return {
      startDate: firstDay.toISOString().split('T')[0],
      endDate: lastDay.toISOString().split('T')[0],
      monthLabel: firstDay.toLocaleString('default', { month: 'long', year: 'numeric' }),
    };
  }, [viewDate]);

  // Generate calendar grid for analytics
  const calendarDays = useMemo(() => {
    const year = viewDate.getFullYear();
    const month = viewDate.getMonth();
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    const startingDayOfWeek = firstDay.getDay();
    const daysInMonth = lastDay.getDate();

    const days: { date: string | null; day: number | null; status?: string }[] = [];

    // Add empty cells for days before the first day
    for (let i = 0; i < startingDayOfWeek; i++) {
      days.push({ date: null, day: null });
    }

    // Add days of the month
    for (let day = 1; day <= daysInMonth; day++) {
      const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
      const status = routineAnalytics?.calendarData[dateStr];
      days.push({ date: dateStr, day, status });
    }

    return days;
  }, [viewDate, routineAnalytics]);

  // Redirect to correct URL if needed
  useEffect(() => {
    if (routines.length === 0) return;

    const urlNumericId = urlRoutineId ? parseInt(urlRoutineId, 10) : null;
    const urlIsValid = urlNumericId !== null && routines.some((r) => r.id === urlNumericId);

    // If no URL or invalid URL, redirect to the selected routine
    if (!urlIsValid && selectedRoutineId !== null) {
      navigate(`/routines/${selectedRoutineId}`, { replace: true });
    }
  }, [routines, urlRoutineId, selectedRoutineId, navigate]);

  // Save to localStorage when selection changes
  useEffect(() => {
    if (selectedRoutineId !== null) {
      localStorage.setItem(LAST_VIEWED_ROUTINE_KEY, selectedRoutineId.toString());
    }
  }, [selectedRoutineId]);

  // Load routine detail when selected
  useEffect(() => {
    if (selectedRoutineId && !routineDetail) {
      loadRoutineDetail(selectedRoutineId);
    }
  }, [selectedRoutineId, routineDetail, loadRoutineDetail]);

  // Update edited name when routine detail loads
  useEffect(() => {
    if (routineDetail) {
      setEditedName(routineDetail.name);
    }
  }, [routineDetail]);

  // Load analytics when toggled on
  useEffect(() => {
    if (showAnalytics && selectedRoutineId) {
      loadAnalytics(selectedRoutineId, startDate, endDate);
    }
  }, [showAnalytics, selectedRoutineId, startDate, endDate, loadAnalytics]);

  const handleSettingsClick = () => {
    navigate('/settings');
  };

  const handleRoutineSelect = (routineId: number) => {
    if (routineId === selectedRoutineId) return;
    navigate(`/routines/${routineId}`, { replace: true });
    setIsSidebarOpen(false);
    setShowAnalytics(false);
    setIsEditingName(false);
    setEditingStepId(null);
  };

  const handleCreateRoutine = async (name: string) => {
    const newRoutine = await createRoutine(name);
    navigate(`/routines/${newRoutine.id}`, { replace: true });
    setIsSidebarOpen(false);
  };

  const handleStartRoutine = async () => {
    if (selectedRoutineId && !isStarting) {
      setIsStarting(true);
      try {
        await startRoutine(selectedRoutineId);
        navigate(`/routines/${selectedRoutineId}/execute`);
      } finally {
        setIsStarting(false);
      }
    }
  };

  const handleContinueExecution = () => {
    if (selectedRoutineId) {
      navigate(`/routines/${selectedRoutineId}/execute`);
    }
  };

  // Name editing handlers
  const handleSaveName = async () => {
    if (selectedRoutineId && editedName.trim() && editedName !== routineDetail?.name) {
      await updateRoutineName(selectedRoutineId, editedName.trim());
    }
    setIsEditingName(false);
  };

  // Step handlers
  const handleAddStep = async () => {
    if (selectedRoutineId && newStepText.trim()) {
      await createStep(selectedRoutineId, newStepText.trim());
      setNewStepText('');
    }
  };

  const handleSaveStepText = async (stepId: number) => {
    if (selectedRoutineId && editedStepText.trim()) {
      await updateStepText(selectedRoutineId, stepId, editedStepText.trim());
    }
    setEditingStepId(null);
  };

  const handleDeleteStep = async (stepId: number) => {
    if (deletingStepId === stepId) {
      if (selectedRoutineId) {
        await deleteStep(selectedRoutineId, stepId);
      }
      setDeletingStepId(null);
    } else {
      setDeletingStepId(stepId);
      setTimeout(() => setDeletingStepId(null), 3000);
    }
  };

  // Drag handlers
  const handleDragStart = (stepId: number) => {
    setDraggedStepId(stepId);
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
  };

  const handleDrop = async (e: React.DragEvent, targetStepId: number) => {
    e.preventDefault();
    if (draggedStepId === null || draggedStepId === targetStepId || !selectedRoutineId || !routineDetail) {
      setDraggedStepId(null);
      return;
    }

    const steps = [...routineDetail.steps].sort((a, b) => a.position - b.position);
    const targetIndex = steps.findIndex((s) => s.id === targetStepId);

    if (targetIndex !== -1) {
      await updateStepPosition(selectedRoutineId, draggedStepId, targetIndex);
    }
    setDraggedStepId(null);
  };

  // Schedule handlers
  const handleSaveSchedules = async (schedules: ScheduleEntry[]) => {
    if (selectedRoutineId) {
      await setSchedules(selectedRoutineId, schedules);
      setIsScheduleModalOpen(false);
    }
  };

  const getScheduleSummary = (): string => {
    if (!routineDetail || routineDetail.schedules.length === 0) {
      return 'No schedule set';
    }

    const scheduledDays = routineDetail.schedules
      .filter((s) => s.promptTime !== null)
      .map((s) => DAYS_OF_WEEK[s.dayOfWeek]);

    if (scheduledDays.length === 0) {
      return 'No prompts scheduled';
    }

    if (scheduledDays.length === 7) {
      return 'Every day';
    }

    return scheduledDays.join(', ');
  };

  // Analytics navigation
  const handlePrevMonth = () => {
    setViewDate((prev) => new Date(prev.getFullYear(), prev.getMonth() - 1, 1));
  };

  const handleNextMonth = () => {
    setViewDate((prev) => new Date(prev.getFullYear(), prev.getMonth() + 1, 1));
  };

  const handleToday = () => {
    setViewDate(new Date());
  };

  const currentRoutine = selectedRoutineId !== null ? routines.find((r) => r.id === selectedRoutineId) : null;
  const sortedSteps = routineDetail ? [...routineDetail.steps].sort((a, b) => a.position - b.position) : [];

  return (
    <div className="routines-page-sidebar">
      <header className="app-header">
        <div className="header-content">
          <div className="header-left">
            <button
              className="btn-hamburger"
              onClick={() => setIsSidebarOpen(!isSidebarOpen)}
              title="Toggle sidebar"
            >
              {isSidebarOpen ? <X size={20} color="#ffffff" /> : <Menu size={20} color="#ffffff" />}
            </button>
            <h1>Todue</h1>
          </div>
          <div className="header-right">
            <div className="header-tabs">
              <button className="header-tab" onClick={() => navigate('/')}>
                Now
              </button>
              <button className="header-tab" onClick={() => navigate('/later')}>
                Later
              </button>
              <button className="header-tab active">Routines</button>
            </div>
            <div className="user-info">
              <button onClick={handleSettingsClick} className="btn-account" title="Settings">
                <User size={20} color="#ffffff" />
              </button>
            </div>
          </div>
        </div>
      </header>

      <div className="sidebar-layout">
        {/* Backdrop for mobile */}
        {isSidebarOpen && <div className="sidebar-backdrop" onClick={() => setIsSidebarOpen(false)} />}

        {/* Sidebar */}
        <aside className={`routines-sidebar ${isSidebarOpen ? 'open' : ''}`}>
          <div className="sidebar-header">
            <h2>Your Routines</h2>
            <button
              className="btn-sidebar-add"
              onClick={() => setIsCreateModalOpen(true)}
              title="New routine"
            >
              <Plus size={18} />
            </button>
          </div>

          <div className="sidebar-routine-container">
            {isLoading && routines.length === 0 ? (
              <div className="sidebar-loading">Loading...</div>
            ) : routines.length === 0 ? (
              <div className="sidebar-empty">No routines yet</div>
            ) : (
              sortedRoutines.map((routine) => (
                <SidebarRoutineItem
                  key={routine.id}
                  routine={routine}
                  isSelected={selectedRoutineId === routine.id}
                  hasActiveExecution={activeExecutions.has(routine.id)}
                  onSelect={() => handleRoutineSelect(routine.id)}
                />
              ))
            )}
          </div>
        </aside>

        {/* Main Content */}
        <main className="routines-main-content-sidebar">
          {error && (
            <div className="error-banner" role="alert">
              {error}
            </div>
          )}

          {routines.length === 0 && !isLoading ? (
            <div className="routines-empty-state">
              <h2>Create a routine to get started</h2>
              <p>Track repeatable checklists like morning routines or workout plans.</p>
              <button className="btn-primary" onClick={() => setIsCreateModalOpen(true)}>
                <Plus size={18} />
                Create Your First Routine
              </button>
            </div>
          ) : currentRoutine && routineDetail ? (
            <div className="routine-detail-container">
              {/* Routine Header */}
              <div className="routine-detail-header-inline">
                {isEditingName ? (
                  <div className="routine-name-edit">
                    <input
                      type="text"
                      value={editedName}
                      onChange={(e) => setEditedName(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') handleSaveName();
                        if (e.key === 'Escape') setIsEditingName(false);
                      }}
                      autoFocus
                    />
                    <button className="btn-icon" onClick={handleSaveName}>
                      <Check size={18} />
                    </button>
                    <button className="btn-icon" onClick={() => setIsEditingName(false)}>
                      <X size={18} />
                    </button>
                  </div>
                ) : (
                  <div className="routine-name-display" onClick={() => setIsEditingName(true)}>
                    <h2>{routineDetail.name}</h2>
                    <Edit2 size={16} className="edit-icon" />
                  </div>
                )}

                <div className="routine-detail-actions">
                  <button
                    className={`btn-analytics-toggle ${showAnalytics ? 'active' : ''}`}
                    onClick={() => setShowAnalytics(!showAnalytics)}
                    title="Toggle analytics"
                  >
                    <BarChart2 size={18} />
                  </button>
                  {hasActiveExecution ? (
                    <button className="btn-primary" onClick={handleContinueExecution}>
                      <Play size={18} fill="currentColor" />
                      Continue
                    </button>
                  ) : (
                    <button
                      className="btn-primary"
                      onClick={handleStartRoutine}
                      disabled={sortedSteps.length === 0 || isStarting}
                    >
                      <Play size={18} />
                      Start
                    </button>
                  )}
                </div>
              </div>

              {/* Analytics Section (toggleable) */}
              {showAnalytics && (
                <div className="routine-analytics-inline">
                  {/* Stats Cards */}
                  <div className="analytics-stats">
                    <div className="stat-card">
                      <Flame size={24} className="stat-icon streak" />
                      <div className="stat-value">{routineAnalytics?.currentStreak ?? 0}</div>
                      <div className="stat-label">Current Streak</div>
                    </div>
                    <div className="stat-card">
                      <Award size={24} className="stat-icon best" />
                      <div className="stat-value">{routineAnalytics?.longestStreak ?? 0}</div>
                      <div className="stat-label">Best Streak</div>
                    </div>
                    <div className="stat-card">
                      <TrendingUp size={24} className="stat-icon rate" />
                      <div className="stat-value">{routineAnalytics?.completionRate?.toFixed(0) ?? 0}%</div>
                      <div className="stat-label">Completion Rate</div>
                    </div>
                  </div>

                  {/* Calendar */}
                  <section className="analytics-calendar">
                    <div className="calendar-header">
                      <button className="btn-icon" onClick={handlePrevMonth}>
                        <ChevronLeft size={20} />
                      </button>
                      <h3>{monthLabel}</h3>
                      <button className="btn-icon" onClick={handleNextMonth}>
                        <ChevronRight size={20} />
                      </button>
                      <button className="btn-secondary btn-today" onClick={handleToday}>
                        Today
                      </button>
                    </div>

                    <div className="calendar-grid">
                      <div className="calendar-weekdays">
                        {DAYS_OF_WEEK.map((day) => (
                          <div key={day} className="weekday">
                            {day}
                          </div>
                        ))}
                      </div>
                      <div className="calendar-days">
                        {calendarDays.map((cell, index) => (
                          <div
                            key={index}
                            className={`calendar-day ${cell.date ? '' : 'empty'} ${
                              cell.status === 'COMPLETED' ? 'completed' : ''
                            } ${cell.status === 'ABANDONED' ? 'abandoned' : ''} ${
                              cell.status === 'IN_PROGRESS' ? 'in-progress' : ''
                            }`}
                          >
                            {cell.day && (
                              <>
                                <span className="day-number">{cell.day}</span>
                                {cell.status && <span className="day-indicator" />}
                              </>
                            )}
                          </div>
                        ))}
                      </div>
                    </div>

                    <div className="calendar-legend">
                      <div className="legend-item">
                        <span className="legend-dot completed" />
                        <span>Completed</span>
                      </div>
                      <div className="legend-item">
                        <span className="legend-dot abandoned" />
                        <span>Abandoned</span>
                      </div>
                      <div className="legend-item">
                        <span className="legend-dot in-progress" />
                        <span>In Progress</span>
                      </div>
                    </div>
                  </section>

                  {/* Step Analytics */}
                  {routineAnalytics && routineAnalytics.stepAnalytics.length > 0 && (
                    <section className="step-analytics">
                      <h3>Step Completion Rates</h3>
                      <div className="step-analytics-list">
                        {routineAnalytics.stepAnalytics.map((step) => (
                          <div key={step.stepId} className="step-analytics-item">
                            <div className="step-analytics-header">
                              <span className="step-text">{step.stepText}</span>
                              <span className="step-rate">{step.completionRate.toFixed(0)}%</span>
                            </div>
                            <div className="step-analytics-bar">
                              <div className="bar-fill" style={{ width: `${step.completionRate}%` }} />
                            </div>
                            <div className="step-analytics-details">
                              <span>{step.completedCount} completed</span>
                              <span>{step.skippedCount} skipped</span>
                            </div>
                          </div>
                        ))}
                      </div>
                    </section>
                  )}

                  {/* Summary */}
                  <section className="analytics-summary">
                    <h3>Summary</h3>
                    <div className="summary-stats">
                      <div className="summary-item">
                        <span className="summary-label">Total Completions</span>
                        <span className="summary-value">{routineAnalytics?.totalCompletions ?? 0}</span>
                      </div>
                      <div className="summary-item">
                        <span className="summary-label">Total Abandoned</span>
                        <span className="summary-value">{routineAnalytics?.totalAbandoned ?? 0}</span>
                      </div>
                    </div>
                  </section>
                </div>
              )}

              {/* Schedule Section */}
              <section className="routine-schedule-section">
                <div className="section-header">
                  <h3>Schedule</h3>
                  <button className="btn-secondary" onClick={() => setIsScheduleModalOpen(true)}>
                    <Clock size={16} />
                    Edit Schedule
                  </button>
                </div>
                <p className="schedule-summary">{getScheduleSummary()}</p>
              </section>

              {/* Steps Section */}
              <section className="routine-steps-section">
                <div className="section-header">
                  <h3>Steps ({sortedSteps.length})</h3>
                </div>

                <div className="routine-steps-list">
                  {sortedSteps.map((step, index) => (
                    <div
                      key={step.id}
                      className={`routine-step-item ${draggedStepId === step.id ? 'dragging' : ''}`}
                      draggable
                      onDragStart={() => handleDragStart(step.id)}
                      onDragOver={handleDragOver}
                      onDrop={(e) => handleDrop(e, step.id)}
                    >
                      <div className="step-drag-handle">
                        <GripVertical size={16} />
                      </div>
                      <span className="step-number">{index + 1}</span>
                      {editingStepId === step.id ? (
                        <div className="step-edit">
                          <input
                            type="text"
                            value={editedStepText}
                            onChange={(e) => setEditedStepText(e.target.value)}
                            onKeyDown={(e) => {
                              if (e.key === 'Enter') handleSaveStepText(step.id);
                              if (e.key === 'Escape') setEditingStepId(null);
                            }}
                            autoFocus
                          />
                          <button className="btn-icon" onClick={() => handleSaveStepText(step.id)}>
                            <Check size={16} />
                          </button>
                          <button className="btn-icon" onClick={() => setEditingStepId(null)}>
                            <X size={16} />
                          </button>
                        </div>
                      ) : (
                        <span
                          className="step-text"
                          onClick={() => {
                            setEditingStepId(step.id);
                            setEditedStepText(step.text);
                          }}
                        >
                          {step.text}
                        </span>
                      )}
                      <button
                        className={`btn-icon btn-delete-step ${deletingStepId === step.id ? 'confirm' : ''}`}
                        onClick={() => handleDeleteStep(step.id)}
                        title={deletingStepId === step.id ? 'Click again to confirm' : 'Delete step'}
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  ))}
                </div>

                <div className="add-step-form">
                  <input
                    type="text"
                    value={newStepText}
                    onChange={(e) => setNewStepText(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter') handleAddStep();
                    }}
                    placeholder="Add a step..."
                  />
                  <button className="btn-primary" onClick={handleAddStep} disabled={!newStepText.trim()}>
                    <Plus size={18} />
                    Add
                  </button>
                </div>
              </section>
            </div>
          ) : isLoading ? (
            <div className="loading-container">
              <div className="loading-spinner">Loading...</div>
            </div>
          ) : null}
        </main>
      </div>

      <CreateRoutineModal
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
        onSubmit={handleCreateRoutine}
      />

      {routineDetail && (
        <ScheduleRoutineModal
          isOpen={isScheduleModalOpen}
          onClose={() => setIsScheduleModalOpen(false)}
          onSave={handleSaveSchedules}
          currentSchedules={routineDetail.schedules}
        />
      )}

    </div>
  );
};

export default RoutinesPage;
