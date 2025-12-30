import React from 'react';
import { useAuth } from '../context/AuthContext';

const HomePage: React.FC = () => {
  const { user, logout } = useAuth();

  const handleLogout = () => {
    logout();
  };

  return (
    <div className="home-page">
      <header className="app-header">
        <h1>Todue</h1>
        <div className="user-info">
          <span>{user?.email}</span>
          <button onClick={handleLogout} className="btn-secondary">
            Logout
          </button>
        </div>
      </header>

      <main className="app-main">
        <p>Welcome to Todue! Todo list UI coming soon...</p>
      </main>
    </div>
  );
};

export default HomePage;
