import React, { useState, useRef, useEffect, type KeyboardEvent } from 'react';
import { X } from 'lucide-react';

interface CreateListModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (listName: string) => Promise<void>;
}

const CreateListModal: React.FC<CreateListModalProps> = ({ isOpen, onClose, onSubmit }) => {
  const [listName, setListName] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen && inputRef.current) {
      inputRef.current.focus();
    }
  }, [isOpen]);

  useEffect(() => {
    if (isOpen) {
      setListName('');
      setError(null);
    }
  }, [isOpen]);

  const handleSubmit = async () => {
    if (listName.trim() === '' || isSubmitting) return;

    setIsSubmitting(true);
    setError(null);
    try {
      await onSubmit(listName.trim());
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create list');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      handleSubmit();
    } else if (e.key === 'Escape') {
      onClose();
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Create New List</h2>
          <button className="btn-close" onClick={onClose}>
            <X size={20} />
          </button>
        </div>

        <div className="modal-body">
          {error && <div className="error-message">{error}</div>}
          <div className="form-group">
            <label htmlFor="list-name">List Name</label>
            <input
              ref={inputRef}
              id="list-name"
              type="text"
              placeholder="e.g., Movies to Watch"
              value={listName}
              onChange={(e) => setListName(e.target.value)}
              onKeyDown={handleKeyDown}
              disabled={isSubmitting}
              maxLength={100}
            />
          </div>
        </div>

        <div className="modal-footer">
          <button
            className="btn-secondary"
            onClick={onClose}
            disabled={isSubmitting}
          >
            Cancel
          </button>
          <button
            className="btn-primary"
            onClick={handleSubmit}
            disabled={isSubmitting || listName.trim() === ''}
          >
            {isSubmitting ? 'Creating...' : 'Create'}
          </button>
        </div>
      </div>
    </div>
  );
};

export default CreateListModal;
