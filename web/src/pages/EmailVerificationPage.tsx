import React, { useState, useEffect, useRef } from 'react';
import { useNavigate, useSearchParams, Link } from 'react-router-dom';
import { authApi } from '../services/authApi';

const isMobile = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);

const EmailVerificationPage: React.FC = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [status, setStatus] = useState<'verifying' | 'success' | 'error'>('verifying');
  const [message, setMessage] = useState('');
  const [onMobile, setOnMobile] = useState(false);
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

        if (isMobile) {
          // Fire the deep link to bring the user into the app (lands on sign-in).
          // Also show the fallback web login button immediately in case the app
          // isn't installed — iOS shows an error alert for unresolved schemes so
          // we let the user have the button ready regardless.
          setOnMobile(true);
          window.location.href = 'todue://';
        } else {
          // Redirect to login after 3 seconds on desktop
          setTimeout(() => {
            navigate('/login');
          }, 3000);
        }
      } catch (err: any) {
        setStatus('error');
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
              Your email has been verified successfully!
            </div>
            {onMobile ? (
              <>
                <p>Opening the Todue app...</p>
                <Link to="/login" className="btn-secondary">
                  Continue in browser instead
                </Link>
              </>
            ) : (
              <>
                <p>Redirecting to login page...</p>
                <Link to="/login" className="btn-primary">
                  Go to Login Now
                </Link>
              </>
            )}
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
