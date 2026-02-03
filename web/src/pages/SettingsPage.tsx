import React, { useState, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Moon, Sun, LogOut, Download, Upload } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { userApi } from '../services/userApi';
import AccentColorPicker from '../components/AccentColorPicker';
import TimezoneSelector from '../components/TimezoneSelector';
import type { ImportFormat, ImportResponse } from '../types';

const SettingsPage: React.FC = () => {
  const { user, logout } = useAuth();
  const { theme, toggleTheme } = useTheme();
  const [timezone, setTimezone] = useState(user?.timezone || 'UTC');
  const navigate = useNavigate();
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Export state
  const [isExporting, setIsExporting] = useState(false);
  const [exportError, setExportError] = useState<string | null>(null);

  // Import state
  const [isImporting, setIsImporting] = useState(false);
  const [importFormat, setImportFormat] = useState<ImportFormat>('TEUXDEUX');
  const [importResult, setImportResult] = useState<ImportResponse | null>(null);
  const [importError, setImportError] = useState<string | null>(null);

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const handleBack = () => {
    navigate('/');
  };

  const handleExport = async () => {
    setIsExporting(true);
    setExportError(null);

    try {
      const data = await userApi.exportData();

      // Create and download file
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `todue-export-${new Date().toISOString().split('T')[0]}.json`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
    } catch (err) {
      setExportError(err instanceof Error ? err.message : 'Failed to export data');
    } finally {
      setIsExporting(false);
    }
  };

  const handleImportClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileSelect = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    setIsImporting(true);
    setImportError(null);
    setImportResult(null);

    try {
      const text = await file.text();
      const data = JSON.parse(text);

      const result = await userApi.importData(importFormat, data);
      setImportResult(result);

      if (!result.success) {
        setImportError(result.message);
      }
    } catch (err) {
      if (err instanceof SyntaxError) {
        setImportError('Invalid JSON file');
      } else {
        setImportError(err instanceof Error ? err.message : 'Failed to import data');
      }
    } finally {
      setIsImporting(false);
      // Reset file input
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
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

            <div className="setting-item">
              <div className="setting-info">
                <span className="setting-label">Accent Color</span>
              </div>
              <AccentColorPicker />
            </div>

            <div className="setting-item">
              <div className="setting-info">
                <span className="setting-label">Timezone</span>
              </div>
              <TimezoneSelector
                value={timezone}
                onChange={async (tz) => {
                  setTimezone(tz);
                  try {
                    await userApi.updateTimezone(tz);
                  } catch (err) {
                    console.error('Failed to update timezone:', err);
                  }
                }}
              />
            </div>
          </div>

          <div className="settings-group">
            <h3>Data</h3>

            <div className="setting-item">
              <div className="setting-info">
                <span className="setting-label">Export Data</span>
                <span className="setting-description">Download all your data as a JSON file</span>
              </div>
              <button
                onClick={handleExport}
                disabled={isExporting}
                className="btn-secondary"
                style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}
              >
                {isExporting ? 'Exporting...' : <>Export <Download size={16} /></>}
              </button>
            </div>
            {exportError && (
              <div className="setting-error">{exportError}</div>
            )}

            <div className="setting-item setting-item-column">
              <div className="setting-info">
                <span className="setting-label">Import Data</span>
                <span className="setting-description">Import data from another app</span>
              </div>
              <div className="import-controls">
                <select
                  value={importFormat}
                  onChange={(e) => setImportFormat(e.target.value as ImportFormat)}
                  className="import-format-select"
                  disabled={isImporting}
                >
                  <option value="TEUXDEUX">TeuxDeux</option>
                  <option value="TODUE">Todue (Backup)</option>
                </select>
                <button
                  onClick={handleImportClick}
                  disabled={isImporting}
                  className="btn-secondary"
                  style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}
                >
                  {isImporting ? 'Importing...' : <>Import <Upload size={16} /></>}
                </button>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".json"
                  onChange={handleFileSelect}
                  style={{ display: 'none' }}
                />
              </div>
            </div>

            {importError && (
              <div className="setting-error">{importError}</div>
            )}

            {importResult && importResult.success && importResult.stats && (
              <div className="import-result">
                <div className="import-result-header">{importResult.message}</div>
                {(importResult.stats.todosImported > 0 ||
                  importResult.stats.recurringTodosImported > 0 ||
                  importResult.stats.laterListsImported > 0 ||
                  importResult.stats.laterListTodosImported > 0 ||
                  importResult.stats.routinesImported > 0 ||
                  importResult.stats.routineStepsImported > 0) && (
                  <div className="import-stats">
                    {importResult.stats.todosImported > 0 && (
                      <div className="import-stat">Todos: {importResult.stats.todosImported}</div>
                    )}
                    {importResult.stats.recurringTodosImported > 0 && (
                      <div className="import-stat">Recurring: {importResult.stats.recurringTodosImported}</div>
                    )}
                    {importResult.stats.laterListsImported > 0 && (
                      <div className="import-stat">Lists: {importResult.stats.laterListsImported}</div>
                    )}
                    {importResult.stats.laterListTodosImported > 0 && (
                      <div className="import-stat">List Items: {importResult.stats.laterListTodosImported}</div>
                    )}
                    {importResult.stats.routinesImported > 0 && (
                      <div className="import-stat">Routines: {importResult.stats.routinesImported}</div>
                    )}
                    {importResult.stats.routineStepsImported > 0 && (
                      <div className="import-stat">Routine Steps: {importResult.stats.routineStepsImported}</div>
                    )}
                  </div>
                )}
                {importResult.stats.warnings.length > 0 && (
                  <div className="import-warnings">
                    <div className="import-warnings-header">Warnings:</div>
                    <ul>
                      {importResult.stats.warnings.map((warning, index) => (
                        <li key={index}>{warning}</li>
                      ))}
                    </ul>
                  </div>
                )}
              </div>
            )}
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
