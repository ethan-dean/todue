import React, { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, Check, SkipForward, Flag, Edit2 } from 'lucide-react';
import { useRoutines } from '../context/RoutineContext';

const RoutineExecutionPage: React.FC = () => {
  const { routineId } = useParams<{ routineId: string }>();
  const navigate = useNavigate();
  const {
    activeExecutions,
    routineDetails,
    loadActiveExecution,
    loadRoutineDetail,
    completeStep,
    finishExecution,
    abandonExecution,
    updateStepNotes,
    error,
  } = useRoutines();

  const [isProcessing, setIsProcessing] = useState(false);
  const [editingStepId, setEditingStepId] = useState<number | null>(null);
  const [notesValue, setNotesValue] = useState('');
  const [selectedStepIndex, setSelectedStepIndex] = useState<number | null>(null);
  const [hasCheckedExecution, setHasCheckedExecution] = useState(false);

  const numericRoutineId = routineId ? parseInt(routineId, 10) : null;
  const execution = numericRoutineId ? activeExecutions.get(numericRoutineId) : null;
  const routineDetail = numericRoutineId ? routineDetails.get(numericRoutineId) : null;

  useEffect(() => {
    if (numericRoutineId) {
      // Load execution if not already present
      if (!activeExecutions.has(numericRoutineId)) {
        loadActiveExecution(numericRoutineId).then(() => {
          setHasCheckedExecution(true);
        });
      } else {
        setHasCheckedExecution(true);
      }
      // Load detail for step notes
      if (!routineDetails.has(numericRoutineId)) {
        loadRoutineDetail(numericRoutineId);
      }
    }
  }, [numericRoutineId, activeExecutions, routineDetails, loadActiveExecution, loadRoutineDetail]);

  // Redirect when no active execution after check
  useEffect(() => {
    if (hasCheckedExecution && !execution && numericRoutineId) {
      navigate(`/routines/${numericRoutineId}`, { replace: true });
    }
  }, [hasCheckedExecution, execution, numericRoutineId, navigate]);

  // Check if all steps are done
  const allStepsDone = execution
    ? execution.stepCompletions.every((sc) => sc.status !== 'PENDING')
    : false;

  // Get first pending step index (for auto-selection after completing a step)
  const firstPendingStepIndex = execution
    ? execution.stepCompletions.findIndex((sc) => sc.status === 'PENDING')
    : -1;

  // Use selected step if set, otherwise default to first pending
  const currentStepIndex = selectedStepIndex !== null ? selectedStepIndex : firstPendingStepIndex;
  const currentStep = currentStepIndex >= 0 ? execution?.stepCompletions[currentStepIndex] : null;

  // Get step notes from routineDetail (the source of truth for step definition notes)
  const getCurrentStepNotes = (): string | null => {
    if (!currentStep || !routineDetail) return currentStep?.stepNotes ?? null;
    const step = routineDetail.steps.find((s) => s.id === currentStep.stepId);
    return step?.notes ?? null;
  };

  const currentStepNotes = getCurrentStepNotes();

  const handleCompleteStep = async () => {
    if (!execution || !currentStep || isProcessing || editingStepId !== null) return;
    setIsProcessing(true);
    try {
      await completeStep(execution.id, currentStep.stepId, 'complete');
      // Reset selection to auto-select first pending step
      setSelectedStepIndex(null);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleSkipStep = async () => {
    if (!execution || !currentStep || isProcessing || editingStepId !== null) return;
    setIsProcessing(true);
    try {
      await completeStep(execution.id, currentStep.stepId, 'skip');
      // Reset selection to auto-select first pending step
      setSelectedStepIndex(null);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleSelectStep = (index: number) => {
    if (isProcessing || editingStepId !== null) return;
    setSelectedStepIndex(index);
  };

  const handleFinish = async () => {
    if (!execution || isProcessing) return;
    setIsProcessing(true);
    try {
      await finishExecution(execution.id);
      navigate(`/routines/${numericRoutineId}`);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleAbandon = async () => {
    if (!execution || isProcessing) return;
    setIsProcessing(true);
    try {
      await abandonExecution(execution.id);
      navigate(`/routines/${numericRoutineId}`);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleStartEditNotes = () => {
    if (!currentStep) return;
    setEditingStepId(currentStep.stepId);
    setNotesValue(currentStepNotes ?? '');
  };

  const handleSaveNotes = async () => {
    if (!numericRoutineId || editingStepId === null) return;
    setIsProcessing(true);
    try {
      await updateStepNotes(numericRoutineId, editingStepId, notesValue.trim() || null);
      setEditingStepId(null);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleCancelEditNotes = () => {
    setEditingStepId(null);
  };

  if (!execution) {
    return (
      <div className="routine-execution-page">
        <header className="execution-header">
          <button className="btn-back" onClick={() => navigate(`/routines/${numericRoutineId}`)}>
            <ArrowLeft size={20} />
          </button>
          <h1>Loading...</h1>
        </header>
        <main className="execution-content">
          <div className="loading-container">
            <div className="loading-spinner">Loading execution...</div>
          </div>
        </main>
      </div>
    );
  }

  const completedCount = execution.completedSteps + execution.skippedSteps;
  const progress = (completedCount / execution.totalSteps) * 100;
  const isEditing = editingStepId !== null;

  return (
    <div className="routine-execution-page">
      <header className="execution-header">
        <button className="btn-back" onClick={() => navigate(`/routines/${numericRoutineId}`)}>
          <ArrowLeft size={20} />
        </button>
        <h1>{execution.routineName}</h1>
        <button className="btn-icon btn-abandon" onClick={handleAbandon} title="Abandon routine">
          <Flag size={20} color="var(--color-danger, #e53e3e)" />
        </button>
      </header>

      {error && (
        <div className="error-banner" role="alert">
          {error}
        </div>
      )}

      {/* Progress Bar */}
      <div className="execution-progress">
        <div className="progress-bar">
          <div className="progress-fill" style={{ width: `${progress}%` }} />
        </div>
        <span className="progress-text">
          {completedCount} of {execution.totalSteps} steps
        </span>
      </div>

      <main className="execution-content">
        {/* Current Step */}
        {currentStep && (
          <div className="current-step-container">
            <div className="current-step-number">
              Step {currentStepIndex + 1} of {execution.totalSteps}
            </div>
            <div className="current-step">
              <h2 className="current-step-text">{currentStep.stepText}</h2>

              {/* Notes Section */}
              {isEditing ? (
                <div className="notes-edit-section">
                  <textarea
                    className="notes-textarea"
                    value={notesValue}
                    onChange={(e) => setNotesValue(e.target.value)}
                    placeholder="Add notes for this step..."
                    rows={3}
                    autoFocus
                  />
                  <div className="notes-edit-actions">
                    <button className="btn-secondary" onClick={handleCancelEditNotes}>
                      Cancel
                    </button>
                    <button
                      className="btn-primary"
                      onClick={handleSaveNotes}
                      disabled={isProcessing}
                    >
                      Save
                    </button>
                  </div>
                </div>
              ) : (
                <div className="notes-display-section" onClick={handleStartEditNotes}>
                  {currentStepNotes ? (
                    <p className="current-step-notes">{currentStepNotes}</p>
                  ) : (
                    <p className="current-step-notes placeholder">Add notes...</p>
                  )}
                  <Edit2 size={16} className="notes-edit-icon" />
                </div>
              )}
            </div>
            <div className="current-step-actions">
              <button
                className="btn-complete"
                onClick={handleCompleteStep}
                disabled={isProcessing || isEditing}
              >
                <Check size={24} />
                Complete
              </button>
              <button
                className="btn-skip"
                onClick={handleSkipStep}
                disabled={isProcessing || isEditing}
              >
                <SkipForward size={24} />
                Skip
              </button>
            </div>
          </div>
        )}

        {/* All Steps List */}
        <div className="execution-steps-list">
          {execution.stepCompletions.map((step, index) => {
            const isSelected = index === currentStepIndex;
            const isPending = step.status === 'PENDING';
            const isCompleted = step.status === 'COMPLETED';
            const isSkipped = step.status === 'SKIPPED';

            return (
              <div
                key={step.id}
                className={`execution-step-item ${isCompleted ? 'completed' : ''} ${isSkipped ? 'skipped' : ''} ${isPending ? 'pending' : ''} ${isSelected ? 'selected' : ''}`}
                onClick={() => handleSelectStep(index)}
              >
                <span className="step-status-icon">
                  {isCompleted ? (
                    <Check size={16} />
                  ) : isSkipped ? (
                    <SkipForward size={16} />
                  ) : (
                    <span className="step-number">{index + 1}</span>
                  )}
                </span>
                <span className="step-text">{step.stepText}</span>
              </div>
            );
          })}
        </div>

        {/* All Done */}
        {allStepsDone && (
          <div className="all-done-container">
            <div className="all-done-message">
              <Check size={48} className="done-icon" />
              <h2>All steps complete!</h2>
              <p>
                {execution.completedSteps} completed, {execution.skippedSteps} skipped
              </p>
            </div>
            <button className="btn-finish" onClick={handleFinish} disabled={isProcessing}>
              Finish Routine
            </button>
          </div>
        )}
      </main>
    </div>
  );
};

export default RoutineExecutionPage;
