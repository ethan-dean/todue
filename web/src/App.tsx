import React from 'react';
import { BrowserRouter, Routes, Route, Navigate, useNavigate } from 'react-router-dom';
import { ThemeProvider } from './context/ThemeContext';
import { AuthProvider } from './context/AuthContext';
import { TodoProvider } from './context/TodoContext';
import { LaterListProvider } from './context/LaterListContext';
import { RoutineProvider, useRoutines } from './context/RoutineContext';
import ProtectedRoute from './components/ProtectedRoute';
import RoutinePromptModal from './components/RoutinePromptModal';
import LoginPage from './pages/LoginPage';
import RegisterPage from './pages/RegisterPage';
import ForgotPasswordPage from './pages/ForgotPasswordPage';
import ResetPasswordPage from './pages/ResetPasswordPage';
import EmailVerificationPage from './pages/EmailVerificationPage';
import LandingPage from './pages/LandingPage';
import TodosPage from './pages/TodosPage';
import SettingsPage from './pages/SettingsPage';
import LaterListsPage from './pages/LaterListsPage';
import RoutinesPage from './pages/RoutinesPage';
import RoutineExecutionPage from './pages/RoutineExecutionPage';
import './App.css';

function GlobalRoutinePrompt() {
  const navigate = useNavigate();
  const { pendingPrompts, startRoutine, dismissPrompt } = useRoutines();
  const [isOpen, setIsOpen] = React.useState(false);

  React.useEffect(() => {
    if (pendingPrompts.length > 0) {
      setIsOpen(true);
    }
  }, [pendingPrompts]);

  const handleStart = async (routineId: number) => {
    await startRoutine(routineId);
    setIsOpen(false);
    navigate(`/routines/${routineId}/execute`);
  };

  const handleDismiss = async (routineId: number) => {
    await dismissPrompt(routineId);
    if (pendingPrompts.length <= 1) {
      setIsOpen(false);
    }
  };

  if (pendingPrompts.length === 0) return null;

  return (
    <RoutinePromptModal
      isOpen={isOpen}
      prompts={pendingPrompts}
      onStart={handleStart}
      onDismiss={handleDismiss}
      onClose={() => setIsOpen(false)}
    />
  );
}

function App() {
  return (
    <ThemeProvider>
      <BrowserRouter>
        <AuthProvider>
          <TodoProvider>
            <LaterListProvider>
              <RoutineProvider>
              <GlobalRoutinePrompt />
              <Routes>
                {/* Public routes */}
                <Route path="/" element={<LandingPage />} />
                <Route path="/login" element={<LoginPage />} />
                <Route path="/register" element={<RegisterPage />} />
                <Route path="/forgot-password" element={<ForgotPasswordPage />} />
                <Route path="/reset-password" element={<ResetPasswordPage />} />
                <Route path="/verify-email" element={<EmailVerificationPage />} />

                {/* Protected routes */}
                <Route
                  path="/app"
                  element={
                    <ProtectedRoute>
                      <TodosPage />
                    </ProtectedRoute>
                  }
                />
                <Route
                  path="/later"
                  element={
                    <ProtectedRoute>
                      <LaterListsPage />
                    </ProtectedRoute>
                  }
                />
                <Route
                  path="/later/:listId"
                  element={
                    <ProtectedRoute>
                      <LaterListsPage />
                    </ProtectedRoute>
                  }
                />
                <Route
                  path="/settings"
                  element={
                    <ProtectedRoute>
                      <SettingsPage />
                    </ProtectedRoute>
                  }
                />
                <Route
                  path="/routines"
                  element={
                    <ProtectedRoute>
                      <RoutinesPage />
                    </ProtectedRoute>
                  }
                />
                <Route
                  path="/routines/:routineId"
                  element={
                    <ProtectedRoute>
                      <RoutinesPage />
                    </ProtectedRoute>
                  }
                />
                <Route
                  path="/routines/:routineId/execute"
                  element={
                    <ProtectedRoute>
                      <RoutineExecutionPage />
                    </ProtectedRoute>
                  }
                />

                {/* Redirect all other routes to home */}
                <Route path="*" element={<Navigate to="/" replace />} />
              </Routes>
              </RoutineProvider>
            </LaterListProvider>
          </TodoProvider>
        </AuthProvider>
      </BrowserRouter>
    </ThemeProvider>
  );
}

export default App;
