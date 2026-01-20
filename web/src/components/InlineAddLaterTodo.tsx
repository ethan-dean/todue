import React, { useState, type KeyboardEvent } from 'react';
import { useLaterLists } from '../context/LaterListContext';

interface InlineAddLaterTodoProps {
  listId: number;
}

const InlineAddLaterTodo: React.FC<InlineAddLaterTodoProps> = ({ listId }) => {
  const { createTodo } = useLaterLists();
  const [text, setText] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async () => {
    if (text.trim() === '') {
      return;
    }

    setIsLoading(true);

    try {
      await createTodo(listId, text.trim());
      setText('');
    } catch (err) {
      console.error('Failed to create todo:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      handleSubmit();
    } else if (e.key === 'Escape') {
      setText('');
    }
  };

  return (
    <div className="todo-item inline-add-todo">
      <div className="todo-checkbox">
        <div className="checkbox-placeholder"></div>
      </div>

      <input
        type="text"
        className="todo-add-input"
        value={text}
        onChange={(e) => setText(e.target.value)}
        onKeyDown={handleKeyDown}
        placeholder="Add an item..."
        disabled={isLoading}
      />

      <div className="todo-actions">
        {/* Empty space to align with other todo items */}
      </div>
    </div>
  );
};

export default InlineAddLaterTodo;
