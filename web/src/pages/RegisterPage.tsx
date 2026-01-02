import React, { useState, type FormEvent } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import PasswordRequirements, { validatePassword } from '../components/PasswordRequirements';

const RegisterPage: React.FC = () => {
  const navigate = useNavigate();
  const { register, error, isLoading, clearError } = useAuth();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [validationError, setValidationError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');

  const validateForm = (): boolean => {
    if (!email.trim()) {
      setValidationError('Email is required');
      return false;
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      setValidationError('Please enter a valid email address');
      return false;
    }

    if (!password) {
      setValidationError('Password is required');
      return false;
    }

    if (!validatePassword(password)) {
      setValidationError('Password does not meet all requirements');
      return false;
    }

    if (password !== confirmPassword) {
      setValidationError('Passwords do not match');
      return false;
    }

    return true;
  };

  const handleSubmit = async (e: FormEvent<HTMLFormElement>): Promise<void> => {
    e.preventDefault();
    setValidationError('');
    clearError();

    if (!validateForm()) {
      return;
    }

    try {
      // Get user's timezone
      const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
      const message = await register(email, password, timezone);
      setSuccessMessage(message);
      // Clear form
      setEmail('');
      setPassword('');
      setConfirmPassword('');
    } catch (err) {
      // Error is handled by AuthContext
      console.error('Registration failed:', err);
    }
  };

  const displayError = validationError || error;

  return (
    <div className="register-page">
      <div className="register-container">
        <h1>Create Your Todue Account</h1>

        {successMessage ? (
          <div className="success-container">
            <div className="success-message" role="alert">
              {successMessage}
            </div>
            <p>Please check your email inbox (and spam folder) for the verification link.</p>
            <Link to="/login" className="btn-primary">
              Go to Login
            </Link>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="register-form">
            {displayError && (
              <div className="error-message" role="alert">
                {displayError}
              </div>
            )}

          <div className="form-group">
            <label htmlFor="email">Email</label>
            <input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="Enter your email"
              disabled={isLoading}
              autoComplete="email"
              autoFocus
            />
          </div>

          <div className="form-group">
            <label htmlFor="password">Password</label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Enter your password"
              disabled={isLoading}
              autoComplete="new-password"
            />
            {password && <PasswordRequirements password={password} />}
          </div>

          <div className="form-group">
            <label htmlFor="confirmPassword">Confirm Password</label>
            <input
              id="confirmPassword"
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              placeholder="Confirm your password"
              disabled={isLoading}
              autoComplete="new-password"
            />
          </div>

            <button
              type="submit"
              className="btn-primary"
              disabled={isLoading}
            >
              {isLoading ? 'Creating account...' : 'Create Account'}
            </button>
          </form>
        )}

        {!successMessage && (
          <div className="register-links">
            <p>
              Already have an account? <Link to="/login">Sign in</Link>
            </p>
          </div>
        )}
      </div>
    </div>
  );
};

export default RegisterPage;
