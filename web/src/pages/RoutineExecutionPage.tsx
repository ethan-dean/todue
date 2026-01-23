import React, { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, Check, SkipForward, MoreVertical, Flag } from 'lucide-react';
import { useRoutines } from '../context/RoutineContext';

const RoutineExecutionPage: React.FC = () => {
  const { routineId } = useParams<{ routineId: string }>();
  const navigate = useNavigate();
  const {
    activeExecutions,
    loadActiveExecution,
    completeStep,
    finishExecution,
    abandonExecution,
    error,
  } = useRoutines();

  const [showMenu, setShowMenu] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);

  const numericRoutineId = routineId ? parseInt(routineId, 10) : null;
  const execution = numericRoutineId ? activeExecutions.get(numericRoutineId) : null;

  useEffect(() => {
    // Only load if we don't already have this execution in state
    // (e.g., from startRoutine which already sets it)
    if (numericRoutineId && !activeExecutions.has(numericRoutineId)) {
      loadActiveExecution(numericRoutineId);
    }
  }, [numericRoutineId, activeExecutions, loadActiveExecution]);

  // Check if all steps are done
  const allStepsDone = execution
    ? execution.stepCompletions.every((sc) => sc.status !== 'PENDING')
    : false;

  // Get current step (first PENDING step)
  const currentStepIndex = execution
    ? execution.stepCompletions.findIndex((sc) => sc.status === 'PENDING')
    : -1;
  const currentStep = currentStepIndex >= 0 ? execution?.stepCompletions[currentStepIndex] : null;

  const handleCompleteStep = async () => {
    if (!execution || !currentStep || isProcessing) return;
    setIsProcessing(true);
    try {
      await completeStep(execution.id, currentStep.stepId, 'complete');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleSkipStep = async () => {
    if (!execution || !currentStep || isProcessing) return;
    setIsProcessing(true);
    try {
      await completeStep(execution.id, currentStep.stepId, 'skip');
    } finally {
      setIsProcessing(false);
    }
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

  return (
    <div className="routine-execution-page">
      <header className="execution-header">
        <button className="btn-back" onClick={() => navigate(`/routines/${numericRoutineId}`)}>
          <ArrowLeft size={20} />
        </button>
        <h1>{execution.routineName}</h1>
        <div className="execution-menu-container">
          <button className="btn-icon" onClick={() => setShowMenu(!showMenu)}>
            <MoreVertical size={20} />
          </button>
          {showMenu && (
            <>
              <div className="menu-backdrop" onClick={() => setShowMenu(false)} />
              <div className="execution-menu">
                <button
                  className="menu-item danger"
                  onClick={() => {
                    setShowMenu(false);
                    handleAbandon();
                  }}
                >
                  <Flag size={16} />
                  Abandon Routine
                </button>
              </div>
            </>
          )}
        </div>
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
        {/* Completed Steps */}
        {currentStepIndex > 0 && (
          <div className="completed-steps">
            {execution.stepCompletions.slice(0, currentStepIndex).map((step) => (
              <div
                key={step.id}
                className={`completed-step ${step.status === 'SKIPPED' ? 'skipped' : ''}`}
              >
                <span className="step-status-icon">
                  {step.status === 'COMPLETED' ? (
                    <Check size={16} />
                  ) : (
                    <SkipForward size={16} />
                  )}
                </span>
                <span className="step-text">{step.stepText}</span>
              </div>
            ))}
          </div>
        )}

        {/* Current Step */}
        {currentStep && (
          <div className="current-step-container">
            <div className="current-step-number">
              Step {currentStepIndex + 1} of {execution.totalSteps}
            </div>
            <div className="current-step">
              <h2 className="current-step-text">{currentStep.stepText}</h2>
              {currentStep.stepNotes && (
                <p className="current-step-notes">{currentStep.stepNotes}</p>
              )}
            </div>
            <div className="current-step-actions">
              <button
                className="btn-complete"
                onClick={handleCompleteStep}
                disabled={isProcessing}
              >
                <Check size={24} />
                Complete
              </button>
              <button
                className="btn-skip"
                onClick={handleSkipStep}
                disabled={isProcessing}
              >
                <SkipForward size={24} />
                Skip
              </button>
            </div>
          </div>
        )}

        {/* Remaining Steps Preview */}
        {currentStepIndex >= 0 && currentStepIndex < execution.totalSteps - 1 && (
          <div className="remaining-steps">
            <h3>Coming up</h3>
            {execution.stepCompletions.slice(currentStepIndex + 1).map((step) => (
              <div key={step.id} className="remaining-step">
                <span className="step-text">{step.stepText}</span>
              </div>
            ))}
          </div>
        )}

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
