import React, { useState, useRef, useEffect, type KeyboardEvent } from 'react';
import { Pencil, Trash2 } from 'lucide-react';
import type { LaterList } from '../types';
import { useLaterLists } from '../context/LaterListContext';

interface SidebarListItemProps {
  list: LaterList;
  isSelected: boolean;
  onSelect: () => void;
}

const SidebarListItem: React.FC<SidebarListItemProps> = ({ list, isSelected, onSelect }) => {
  const { updateListName, deleteList } = useLaterLists();
  const [isEditing, setIsEditing] = useState(false);
  const [editName, setEditName] = useState(list.listName);
  const [isLoading, setIsLoading] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isEditing && inputRef.current) {
      inputRef.current.focus();
      inputRef.current.select();
    }
  }, [isEditing]);

  const handleEdit = (e: React.MouseEvent) => {
    e.stopPropagation();
    setEditName(list.listName);
    setIsEditing(true);
  };

  const handleSaveEdit = async () => {
    if (editName.trim() === '') {
      setEditName(list.listName);
      setIsEditing(false);
      return;
    }

    if (editName === list.listName) {
      setIsEditing(false);
      return;
    }

    setIsLoading(true);
    try {
      await updateListName(list.id, editName);
      setIsEditing(false);
    } catch (err) {
      console.error('Failed to update list name:', err);
      setEditName(list.listName);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCancelEdit = () => {
    setEditName(list.listName);
    setIsEditing(false);
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      handleSaveEdit();
    } else if (e.key === 'Escape') {
      handleCancelEdit();
    }
  };

  const handleDelete = async (e: React.MouseEvent) => {
    e.stopPropagation();
    if (window.confirm(`Delete "${list.listName}"? This will delete all todos in this list.`)) {
      setIsLoading(true);
      try {
        await deleteList(list.id);
      } catch (err) {
        console.error('Failed to delete list:', err);
      } finally {
        setIsLoading(false);
      }
    }
  };

  return (
    <div
      className={`sidebar-list-item ${isSelected ? 'selected' : ''} ${isLoading ? 'loading' : ''}`}
      onClick={isEditing ? undefined : onSelect}
    >
      {isEditing ? (
        <input
          ref={inputRef}
          type="text"
          className="sidebar-list-edit-input"
          value={editName}
          onChange={(e) => setEditName(e.target.value)}
          onBlur={handleSaveEdit}
          onKeyDown={handleKeyDown}
          onClick={(e) => e.stopPropagation()}
          disabled={isLoading}
        />
      ) : (
        <span className="sidebar-list-name">{list.listName}</span>
      )}

      <div className="sidebar-list-actions">
        {!isEditing && (
          <button
            className="btn-sidebar-action"
            onClick={handleEdit}
            disabled={isLoading}
            title="Rename"
          >
            <Pencil size={14} />
          </button>
        )}
        <button
          className="btn-sidebar-action btn-sidebar-delete"
          onClick={handleDelete}
          disabled={isLoading}
          title="Delete"
        >
          <Trash2 size={14} />
        </button>
      </div>
    </div>
  );
};

export default SidebarListItem;
