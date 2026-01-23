import React, { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import type { RoutineSchedule, ScheduleEntry } from '../types';

interface ScheduleRoutineModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSave: (schedules: ScheduleEntry[]) => Promise<void>;
  currentSchedules: RoutineSchedule[];
}

const DAYS_OF_WEEK = [
  { value: 0, label: 'Sunday' },
  { value: 1, label: 'Monday' },
  { value: 2, label: 'Tuesday' },
  { value: 3, label: 'Wednesday' },
  { value: 4, label: 'Thursday' },
  { value: 5, label: 'Friday' },
  { value: 6, label: 'Saturday' },
];

const ScheduleRoutineModal: React.FC<ScheduleRoutineModalProps> = ({
  isOpen,
  onClose,
  onSave,
  currentSchedules,
}) => {
  const [schedules, setSchedules] = useState<Map<number, string | null>>(new Map());
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (isOpen) {
      // Initialize from current schedules
      const newSchedules = new Map<number, string | null>();
      currentSchedules.forEach((s) => {
        newSchedules.set(s.dayOfWeek, s.promptTime);
      });
      setSchedules(newSchedules);
      setError(null);
    }
  }, [isOpen, currentSchedules]);

  const handleDayToggle = (day: number) => {
    setSchedules((prev) => {
      const newSchedules = new Map(prev);
      if (newSchedules.has(day)) {
        newSchedules.delete(day);
      } else {
        newSchedules.set(day, '08:00:00');
      }
      return newSchedules;
    });
  };

  const handleTimeChange = (day: number, time: string) => {
    setSchedules((prev) => {
      const newSchedules = new Map(prev);
      // Convert HH:mm to HH:mm:ss format
      const timeWithSeconds = time ? `${time}:00` : null;
      newSchedules.set(day, timeWithSeconds);
      return newSchedules;
    });
  };

  const handleSave = async () => {
    setIsSubmitting(true);
    setError(null);
    try {
      const scheduleEntries: ScheduleEntry[] = [];
      schedules.forEach((promptTime, dayOfWeek) => {
        scheduleEntries.push({ dayOfWeek, promptTime });
      });
      await onSave(scheduleEntries);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save schedules');
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content schedule-modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Schedule Routine</h2>
          <button className="btn-close" onClick={onClose}>
            <X size={20} />
          </button>
        </div>
        <div className="modal-body">
          {error && <div className="modal-error">{error}</div>}
          <p className="schedule-description">
            Select which days you want to be prompted to do this routine, and optionally set a specific time.
          </p>
          <div className="schedule-days">
            {DAYS_OF_WEEK.map((day) => {
              const isEnabled = schedules.has(day.value);
              const promptTime = schedules.get(day.value);
              // Convert HH:mm:ss to HH:mm for input
              const timeValue = promptTime ? promptTime.substring(0, 5) : '08:00';

              return (
                <div key={day.value} className="schedule-day-row">
                  <label className="schedule-day-toggle">
                    <input
                      type="checkbox"
                      checked={isEnabled}
                      onChange={() => handleDayToggle(day.value)}
                    />
                    <span className="day-label">{day.label}</span>
                  </label>
                  {isEnabled && (
                    <input
                      type="time"
                      value={timeValue}
                      onChange={(e) => handleTimeChange(day.value, e.target.value)}
                      className="schedule-time-input"
                    />
                  )}
                </div>
              );
            })}
          </div>
        </div>
        <div className="modal-footer">
          <button type="button" className="btn-secondary" onClick={onClose}>
            Cancel
          </button>
          <button className="btn-primary" onClick={handleSave} disabled={isSubmitting}>
            {isSubmitting ? 'Saving...' : 'Save Schedule'}
          </button>
        </div>
      </div>
    </div>
  );
};

export default ScheduleRoutineModal;
