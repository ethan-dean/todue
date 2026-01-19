import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { User, Plus } from 'lucide-react';
import { useLaterLists } from '../context/LaterListContext';
import LaterListItem from '../components/LaterListItem';
import CreateListModal from '../components/CreateListModal';

const LaterListsPage: React.FC = () => {
  const { lists, isLoading, error, createList } = useLaterLists();
  const navigate = useNavigate();
  const [isModalOpen, setIsModalOpen] = useState(false);

  const handleSettingsClick = () => {
    navigate('/settings');
  };

  const handleListClick = (listId: number) => {
    navigate(`/later/${listId}`);
  };

  const handleCreateList = async (listName: string) => {
    const newList = await createList(listName);
    navigate(`/later/${newList.id}`);
  };

  return (
    <div className="later-lists-page">
      <header className="app-header">
        <div className="header-content">
          <h1>Todue</h1>
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

        {isLoading ? (
          <div className="loading-container">
            <div className="loading-spinner">Loading lists...</div>
          </div>
        ) : (
          <div className="later-lists-container">
            <div className="lists-header">
              <h2>Your Lists</h2>
              <button
                className="btn-create-list"
                onClick={() => setIsModalOpen(true)}
              >
                <Plus size={20} />
                New List
              </button>
            </div>

            {lists.length === 0 ? (
              <div className="lists-empty">
                <p>No lists yet. Create one to get started!</p>
                <button
                  className="btn-primary"
                  onClick={() => setIsModalOpen(true)}
                >
                  Create Your First List
                </button>
              </div>
            ) : (
              <div className="lists-grid">
                {lists.map((list) => (
                  <LaterListItem
                    key={list.id}
                    list={list}
                    onClick={() => handleListClick(list.id)}
                  />
                ))}
              </div>
            )}
          </div>
        )}
      </main>

      <CreateListModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onSubmit={handleCreateList}
      />
    </div>
  );
};

export default LaterListsPage;
