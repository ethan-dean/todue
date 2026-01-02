import React, { useState, useEffect, useRef } from 'react';
import { useNavigate, useSearchParams, Link } from 'react-router-dom';
import { authApi } from '../services/authApi';

const EmailVerificationPage: React.FC = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [status, setStatus] = useState<'verifying' | 'success' | 'error'>('verifying');
  const [message, setMessage] = useState('');
  const hasVerifiedRef = useRef(false);

  useEffect(() => {
    const verifyEmail = async () => {
      // Prevent double execution in React StrictMode
      if (hasVerifiedRef.current) {
        return;
      }
      hasVerifiedRef.current = true;

      const token = searchParams.get('token');

      if (!token) {
        setStatus('error');
        setMessage('Invalid verification link. No token provided.');
        return;
      }

      try {
        const response = await authApi.verifyEmail(token);
        setStatus('success');
        setMessage(response.message);

        // Redirect to login after 3 seconds
        setTimeout(() => {
          navigate('/login');
        }, 3000);
      } catch (err: any) {
        setStatus('error');
        // Extract error message from backend response
        const errorMessage = err?.response?.data?.message || err?.message || 'Email verification failed. The link may have expired or is invalid.';
        setMessage(errorMessage);
      }
    };

    verifyEmail();
  }, [searchParams, navigate]);

  return (
    <div className="email-verification-page">
      <div className="verification-container">
        <h1>Email Verification</h1>

        {status === 'verifying' && (
          <div className="verification-status">
            <p>Verifying your email address...</p>
          </div>
        )}

        {status === 'success' && (
          <div className="success-container">
            <div className="success-message" role="alert">
              {message}
            </div>
            <p>Your email has been verified successfully!</p>
            <p>Redirecting to login page...</p>
            <Link to="/login" className="btn-primary">
              Go to Login Now
            </Link>
          </div>
        )}

        {status === 'error' && (
          <div className="error-container">
            <div className="error-message" role="alert">
              {message}
            </div>
            {(message.includes('already verified') || message.includes('already been used')) ? (
              <Link to="/login" className="btn-primary">
                Go to Login
              </Link>
            ) : (
              <div className="verification-links">
                <Link to="/register" className="btn-primary">
                  Back to Register
                </Link>
                <Link to="/login" className="btn-secondary">
                  Go to Login
                </Link>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default EmailVerificationPage;
