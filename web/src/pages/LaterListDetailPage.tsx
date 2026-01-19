import React, { useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { User, ArrowLeft } from 'lucide-react';
import { useLaterLists } from '../context/LaterListContext';
import LaterListTodoList from '../components/LaterListTodoList';

const LaterListDetailPage: React.FC = () => {
  const { listId } = useParams<{ listId: string }>();
  const navigate = useNavigate();
  const { lists, todos, currentListId, setCurrentListId, isLoading, error } = useLaterLists();

  const numericListId = listId ? parseInt(listId, 10) : null;
  const list = lists.find((l) => l.id === numericListId);
  const listTodos = numericListId ? todos.get(numericListId) || [] : [];

  useEffect(() => {
    if (numericListId !== null) {
      setCurrentListId(numericListId);
    }
    return () => {
      setCurrentListId(null);
    };
  }, [numericListId, setCurrentListId]);

  const handleSettingsClick = () => {
    navigate('/settings');
  };

  const handleBack = () => {
    navigate('/later');
  };

  if (!numericListId || (!list && !isLoading)) {
    return (
      <div className="later-list-detail-page">
        <header className="app-header">
          <div className="header-content">
            <h1>Todue</h1>
            <div className="header-right">
              <div className="user-info">
                <button
                  onClick={handleSettingsClick}
                  className="btn-account"
                  title="Settings"
                >
                  <User size={20} color="#ffffff" />
                </button>
              </div>
            </div>
          </div>
        </header>
        <main className="app-main">
          <div className="error-banner">List not found</div>
          <button className="btn-primary" onClick={handleBack}>
            Back to Lists
          </button>
        </main>
      </div>
    );
  }

  return (
    <div className="later-list-detail-page">
      <header className="app-header">
        <div className="header-content">
          <div className="header-left">
            <button className="btn-back" onClick={handleBack} title="Back to lists">
              <ArrowLeft size={20} color="#ffffff" />
            </button>
            <h1>{list?.listName || 'Loading...'}</h1>
          </div>
          <div className="header-right">
            <div className="header-tabs">
              <button
                className="header-tab"
                onClick={() => navigate('/')}
              >
                Now
              </button>
              <button
                className="header-tab active"
              >
                Later
              </button>
            </div>
            <div className="user-info">
              <button
                onClick={handleSettingsClick}
                className="btn-account"
                title="Settings"
              >
                <User size={20} color="#ffffff" />
              </button>
            </div>
          </div>
        </div>
      </header>

      <main className="app-main">
        {error && (
          <div className="error-banner" role="alert">
            {error}
          </div>
        )}

        {isLoading && currentListId === numericListId ? (
          <div className="loading-container">
            <div className="loading-spinner">Loading todos...</div>
          </div>
        ) : (
          <div className="later-list-detail-container">
            <LaterListTodoList listId={numericListId} todos={listTodos} />
          </div>
        )}
      </main>
    </div>
  );
};

export default LaterListDetailPage;
