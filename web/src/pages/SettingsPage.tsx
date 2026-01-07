import React from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Moon, Sun, LogOut } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';

const SettingsPage: React.FC = () => {
  const { user, logout } = useAuth();
  const { theme, toggleTheme } = useTheme();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const handleBack = () => {
    navigate('/');
  };

  return (
    <div className="settings-page">
      <header className="app-header">
        <div className="header-content">
          <div className="header-left">
            <button onClick={handleBack} className="btn-icon" title="Back to Todos">
              <ArrowLeft size={24} />
            </button>
            <h1>Settings</h1>
          </div>
        </div>
      </header>

      <main className="app-main settings-container">
        <div className="settings-card">
          <div className="user-profile-section">
            <div className="avatar-large">
              {user?.email?.charAt(0).toUpperCase() || 'U'}
            </div>
            <h2 className="user-email-large">{user?.email}</h2>
          </div>

          <div className="settings-group">
            <h3>Preferences</h3>
            
            <div className="setting-item">
              <div className="setting-info">
                <span className="setting-label">Theme</span>
                <span className="setting-value">{theme === 'light' ? 'Light Mode' : 'Dark Mode'}</span>
              </div>
              <button 
                onClick={toggleTheme} 
                className="btn-secondary"
                title={`Switch to ${theme === 'light' ? 'dark' : 'light'} mode`}
                style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}
              >
                {theme === 'light' ? (
                  <>Switch to Dark <Moon size={16} /></>
                ) : (
                  <>Switch to Light <Sun size={16} /></>
                )}
              </button>
            </div>
          </div>

          <div className="settings-group">
            <h3>Account</h3>
            <div className="setting-item">
              <div className="setting-info">
                <span className="setting-label">Sign Out</span>
                <span className="setting-description">Log out of your account on this device</span>
              </div>
              <button onClick={handleLogout} className="btn-logout" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                Logout <LogOut size={16} />
              </button>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
};

export default SettingsPage;
