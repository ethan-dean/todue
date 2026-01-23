import React, { useState, useEffect } from 'react';
import { X, Play, Clock, Check, ChevronDown } from 'lucide-react';
import type { PendingRoutinePrompt, RoutineStep } from '../types';
import { useRoutines } from '../context/RoutineContext';

interface RoutinePromptModalProps {
  isOpen: boolean;
  prompts: PendingRoutinePrompt[];
  onStart: (routineId: number) => Promise<void>;
  onDismiss: (routineId: number) => Promise<void>;
  onClose: () => void;
}

const RoutinePromptModal: React.FC<RoutinePromptModalProps> = ({
  isOpen,
  prompts,
  onStart,
  onDismiss,
  onClose,
}) => {
  const { quickCompleteRoutine, loadRoutineDetail, routineDetails } = useRoutines();
  const [dropdownOpenId, setDropdownOpenId] = useState<number | null>(null);
  const [partialRoutineId, setPartialRoutineId] = useState<number | null>(null);
  const [checkedSteps, setCheckedSteps] = useState<Set<number>>(new Set());
  const [isProcessing, setIsProcessing] = useState(false);

  // Load routine detail when partial mode is opened
  useEffect(() => {
    if (partialRoutineId && !routineDetails.has(partialRoutineId)) {
      loadRoutineDetail(partialRoutineId);
    }
  }, [partialRoutineId, routineDetails, loadRoutineDetail]);

  // Initialize all steps as checked when detail loads
  useEffect(() => {
    if (partialRoutineId) {
      const detail = routineDetails.get(partialRoutineId);
      if (detail) {
        setCheckedSteps(new Set(detail.steps.map((s) => s.id)));
      }
    }
  }, [partialRoutineId, routineDetails]);

  if (!isOpen || prompts.length === 0) return null;

  const formatTime = (time: string | null): string => {
    if (!time) return '';
    const [hours, minutes] = time.split(':').map(Number);
    const ampm = hours >= 12 ? 'PM' : 'AM';
    const hour12 = hours % 12 || 12;
    return `${hour12}:${String(minutes).padStart(2, '0')} ${ampm}`;
  };

  const handleAlreadyDone = async (routineId: number) => {
    setIsProcessing(true);
    setDropdownOpenId(null);
    try {
      await quickCompleteRoutine(routineId);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleOpenPartial = (routineId: number) => {
    setDropdownOpenId(null);
    setPartialRoutineId(routineId);
    setCheckedSteps(new Set());
  };

  const handleToggleStep = (stepId: number) => {
    setCheckedSteps((prev) => {
      const newSet = new Set(prev);
      if (newSet.has(stepId)) {
        newSet.delete(stepId);
      } else {
        newSet.add(stepId);
      }
      return newSet;
    });
  };

  const handleSubmitPartial = async () => {
    if (!partialRoutineId) return;
    setIsProcessing(true);
    try {
      const completedStepIds = Array.from(checkedSteps);
      await quickCompleteRoutine(partialRoutineId, completedStepIds);
      setPartialRoutineId(null);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleCancelPartial = () => {
    setPartialRoutineId(null);
    setCheckedSteps(new Set());
  };

  const partialDetail = partialRoutineId ? routineDetails.get(partialRoutineId) : null;
  const partialSteps: RoutineStep[] = partialDetail
    ? [...partialDetail.steps].sort((a, b) => a.position - b.position)
    : [];

  // Show partial completion view
  if (partialRoutineId) {
    const prompt = prompts.find((p) => p.routineId === partialRoutineId);
    return (
      <div className="modal-overlay" onClick={handleCancelPartial}>
        <div className="modal-content prompt-modal" onClick={(e) => e.stopPropagation()}>
          <div className="modal-header">
            <h2>{prompt?.routineName ?? 'Routine'} - Mark Steps</h2>
            <button className="btn-close" onClick={handleCancelPartial}>
              <X size={20} />
            </button>
          </div>
          <div className="modal-body">
            <p className="partial-instructions">Uncheck any steps you didn't complete:</p>
            {partialSteps.length === 0 ? (
              <div className="partial-loading">Loading steps...</div>
            ) : (
              <div className="partial-steps-list">
                {partialSteps.map((step) => (
                  <label key={step.id} className="partial-step-item">
                    <input
                      type="checkbox"
                      checked={checkedSteps.has(step.id)}
                      onChange={() => handleToggleStep(step.id)}
                      disabled={isProcessing}
                    />
                    <span className="partial-step-text">{step.text}</span>
                  </label>
                ))}
              </div>
            )}
          </div>
          <div className="modal-footer">
            <button className="btn-secondary" onClick={handleCancelPartial} disabled={isProcessing}>
              Cancel
            </button>
            <button
              className="btn-primary"
              onClick={handleSubmitPartial}
              disabled={isProcessing || partialSteps.length === 0}
            >
              <Check size={16} />
              Mark Done
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content prompt-modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Time for Your Routine{prompts.length > 1 ? 's' : ''}</h2>
          <button className="btn-close" onClick={onClose}>
            <X size={20} />
          </button>
        </div>
        <div className="modal-body">
          <div className="prompt-list">
            {prompts.map((prompt) => (
              <div key={prompt.routineId} className="prompt-item">
                <div className="prompt-info">
                  <h3>{prompt.routineName}</h3>
                  <div className="prompt-meta">
                    <span>{prompt.stepCount} steps</span>
                    {prompt.scheduledTime && (
                      <>
                        <span className="separator">·</span>
                        <span className="scheduled-time">
                          <Clock size={14} />
                          {formatTime(prompt.scheduledTime)}
                        </span>
                      </>
                    )}
                  </div>
                </div>
                <div className="prompt-actions">
                  <button
                    className="btn-primary"
                    onClick={() => onStart(prompt.routineId)}
                    disabled={isProcessing}
                  >
                    <Play size={16} />
                    Start
                  </button>
                  <div className="btn-done-group">
                    <button
                      className="btn-done"
                      onClick={() => handleAlreadyDone(prompt.routineId)}
                      disabled={isProcessing}
                    >
                      <Check size={16} />
                      Already Done
                    </button>
                    <button
                      className="btn-done-dropdown"
                      onClick={() =>
                        setDropdownOpenId(dropdownOpenId === prompt.routineId ? null : prompt.routineId)
                      }
                      disabled={isProcessing}
                    >
                      <ChevronDown size={14} />
                    </button>
                    {dropdownOpenId === prompt.routineId && (
                      <>
                        <div className="dropdown-backdrop" onClick={() => setDropdownOpenId(null)} />
                        <div className="btn-done-menu">
                          <button
                            className="dropdown-item"
                            onClick={() => handleOpenPartial(prompt.routineId)}
                          >
                            Partially Done
                          </button>
                        </div>
                      </>
                    )}
                  </div>
                  <button
                    className="btn-secondary"
                    onClick={() => onDismiss(prompt.routineId)}
                    disabled={isProcessing}
                  >
                    Later
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

export default RoutinePromptModal;
