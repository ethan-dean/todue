import React, { useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { authApi } from '../services/authApi';
import { handleApiError } from '../services/api';

const ForgotPasswordPage: React.FC = () => {
  const [email, setEmail] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [validationError, setValidationError] = useState('');

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

    return true;
  };

  const handleSubmit = async (e: FormEvent<HTMLFormElement>): Promise<void> => {
    e.preventDefault();
    setValidationError('');
    setError('');
    setSuccess(false);

    if (!validateForm()) {
      return;
    }

    setIsLoading(true);

    try {
      await authApi.requestPasswordReset(email);
      setSuccess(true);
      setEmail('');
    } catch (err) {
      const errorMessage = handleApiError(err);
      setError(errorMessage);
    } finally {
      setIsLoading(false);
    }
  };

  const displayError = validationError || error;

  return (
    <div className="forgot-password-page">
      <div className="forgot-password-container">
        <h1>Reset Your Password</h1>

        {success ? (
          <div className="success-message">
            <p>
              If an account exists with that email address, you will receive a
              password reset link shortly.
            </p>
            <p>Please check your email and follow the instructions.</p>
            <Link to="/login" className="btn-primary">
              Return to Sign In
            </Link>
          </div>
        ) : (
          <>
            <p className="instruction-text">
              Enter your email address and we'll send you a link to reset your password.
            </p>

            <form onSubmit={handleSubmit} className="forgot-password-form">
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

              <button
                type="submit"
                className="btn-primary"
                disabled={isLoading}
              >
                {isLoading ? 'Sending...' : 'Send Reset Link'}
              </button>
            </form>

            <div className="forgot-password-links">
              <Link to="/login">Back to Sign In</Link>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

export default ForgotPasswordPage;
