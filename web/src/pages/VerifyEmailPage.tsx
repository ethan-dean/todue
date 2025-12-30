import React, { useState, useEffect } from 'react';
import { useNavigate, useSearchParams, Link } from 'react-router-dom';
import { authApi } from '../services/authApi';
import { handleApiError } from '../services/api';

const VerifyEmailPage: React.FC = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();

  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  useEffect(() => {
    const verifyEmailToken = async () => {
      const token = searchParams.get('token');

      if (!token) {
        setError('Invalid or missing verification token.');
        setIsLoading(false);
        return;
      }

      try {
        await authApi.verifyEmail(token);
        setSuccess(true);
        // Redirect to login after 3 seconds
        setTimeout(() => {
          navigate('/login');
        }, 3000);
      } catch (err) {
        const errorMessage = handleApiError(err);
        setError(errorMessage);
      } finally {
        setIsLoading(false);
      }
    };

    verifyEmailToken();
  }, [searchParams, navigate]);

  if (isLoading) {
    return (
      <div className="verify-email-page">
        <div className="verify-email-container">
          <h1>Verifying Your Email</h1>
          <p className="loading-text">Please wait while we verify your email address...</p>
        </div>
      </div>
    );
  }

  if (success) {
    return (
      <div className="verify-email-page">
        <div className="verify-email-container">
          <h1>Email Verified!</h1>
          <div className="success-message">
            <p>Your email has been verified successfully!</p>
            <p>You can now sign in to your account.</p>
            <p className="redirect-text">Redirecting to sign in...</p>
          </div>
          <Link to="/login" className="btn-primary">
            Go to Sign In
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="verify-email-page">
      <div className="verify-email-container">
        <h1>Email Verification Failed</h1>
        <div className="error-message" role="alert">
          {error}
        </div>
        <p className="instruction-text">
          The verification link may have expired or is invalid. Please try registering again or contact support.
        </p>
        <div className="verify-email-links">
          <Link to="/register" className="btn-primary">
            Back to Registration
          </Link>
          <Link to="/login">Already have an account? Sign in</Link>
        </div>
      </div>
    </div>
  );
};

export default VerifyEmailPage;
