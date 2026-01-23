import React, { useState, useEffect, useMemo } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { User, Plus, Menu, X } from 'lucide-react';
import { useLaterLists } from '../context/LaterListContext';
import SidebarListItem from '../components/SidebarListItem';
import LaterListTodoList from '../components/LaterListTodoList';
import CreateListModal from '../components/CreateListModal';

const LAST_VIEWED_LIST_KEY = 'todue_last_viewed_list';

const LaterListsPage: React.FC = () => {
  const { listId: urlListId } = useParams<{ listId: string }>();
  const navigate = useNavigate();
  const { lists, todos, setCurrentListId, isLoading, error, createList } = useLaterLists();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);

  // Get sorted lists
  const sortedLists = useMemo(() =>
    [...lists].sort((a, b) => a.listName.localeCompare(b.listName)),
    [lists]
  );

  // Derive the selected list ID from URL or fallbacks - single source of truth
  const selectedListId = useMemo((): number | null => {
    // Priority 1: URL param if valid
    if (urlListId) {
      const numericId = parseInt(urlListId, 10);
      if (lists.some((l) => l.id === numericId)) {
        return numericId;
      }
    }

    // Priority 2: localStorage if valid
    const savedListId = localStorage.getItem(LAST_VIEWED_LIST_KEY);
    if (savedListId) {
      const numericId = parseInt(savedListId, 10);
      if (lists.some((l) => l.id === numericId)) {
        return numericId;
      }
    }

    // Priority 3: First list alphabetically
    if (sortedLists.length > 0) {
      return sortedLists[0].id;
    }

    // Priority 4: No lists
    return null;
  }, [urlListId, lists, sortedLists]);

  // Sync context's currentListId with our derived selectedListId
  useEffect(() => {
    setCurrentListId(selectedListId);
  }, [selectedListId, setCurrentListId]);

  // Redirect to correct URL if needed (only once when lists load or URL is invalid)
  useEffect(() => {
    if (lists.length === 0) return;

    const urlNumericId = urlListId ? parseInt(urlListId, 10) : null;
    const urlIsValid = urlNumericId !== null && lists.some((l) => l.id === urlNumericId);

    // If no URL or invalid URL, redirect to the selected list
    if (!urlIsValid && selectedListId !== null) {
      navigate(`/later/${selectedListId}`, { replace: true });
    }
  }, [lists, urlListId, selectedListId, navigate]);

  // Save to localStorage when selection changes
  useEffect(() => {
    if (selectedListId !== null) {
      localStorage.setItem(LAST_VIEWED_LIST_KEY, selectedListId.toString());
    }
  }, [selectedListId]);

  const handleSettingsClick = () => {
    navigate('/settings');
  };

  const handleListSelect = (listId: number) => {
    if (listId === selectedListId) return;
    navigate(`/later/${listId}`, { replace: true });
    setIsSidebarOpen(false);
  };

  const handleCreateList = async (listName: string) => {
    const newList = await createList(listName);
    navigate(`/later/${newList.id}`, { replace: true });
    setIsSidebarOpen(false);
  };

  const currentList = selectedListId !== null ? lists.find((l) => l.id === selectedListId) : null;
  const listTodos = selectedListId !== null ? todos.get(selectedListId) || [] : [];

  return (
    <div className="later-lists-page">
      <header className="app-header">
        <div className="header-content">
          <div className="header-left">
            <button
              className="btn-hamburger"
              onClick={() => setIsSidebarOpen(!isSidebarOpen)}
              title="Toggle sidebar"
            >
              {isSidebarOpen ? <X size={20} color="#ffffff" /> : <Menu size={20} color="#ffffff" />}
            </button>
            <h1>Todue</h1>
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
              <button
                className="header-tab"
                onClick={() => navigate('/routines')}
              >
                Routines
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

      <div className="sidebar-layout">
        {/* Backdrop for mobile */}
        {isSidebarOpen && (
          <div
            className="sidebar-backdrop"
            onClick={() => setIsSidebarOpen(false)}
          />
        )}

        {/* Sidebar */}
        <aside className={`lists-sidebar ${isSidebarOpen ? 'open' : ''}`}>
          <div className="sidebar-header">
            <h2>Your Lists</h2>
            <button
              className="btn-sidebar-add"
              onClick={() => setIsModalOpen(true)}
              title="New list"
            >
              <Plus size={18} />
            </button>
          </div>

          <div className="sidebar-list-container">
            {isLoading && lists.length === 0 ? (
              <div className="sidebar-loading">Loading...</div>
            ) : lists.length === 0 ? (
              <div className="sidebar-empty">No lists yet</div>
            ) : (
              sortedLists.map((list) => (
                <SidebarListItem
                  key={list.id}
                  list={list}
                  isSelected={selectedListId === list.id}
                  onSelect={() => handleListSelect(list.id)}
                />
              ))
            )}
          </div>
        </aside>

        {/* Main Content */}
        <main className="lists-main-content">
          {error && (
            <div className="error-banner" role="alert">
              {error}
            </div>
          )}

          {lists.length === 0 && !isLoading ? (
            <div className="lists-empty-state">
              <h2>Create a list to get started</h2>
              <p>Organize your future tasks in lists</p>
              <button
                className="btn-primary"
                onClick={() => setIsModalOpen(true)}
              >
                <Plus size={18} />
                Create Your First List
              </button>
            </div>
          ) : currentList ? (
            <div key={selectedListId} className="list-detail-container">
              <h2 className="list-detail-title">{currentList.listName}</h2>
              <LaterListTodoList listId={selectedListId!} todos={listTodos} />
            </div>
          ) : isLoading ? (
            <div className="loading-container">
              <div className="loading-spinner">Loading...</div>
            </div>
          ) : null}
        </main>
      </div>

      <CreateListModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onSubmit={handleCreateList}
      />
    </div>
  );
};

export default LaterListsPage;
