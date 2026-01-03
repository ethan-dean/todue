import React, { useState, type KeyboardEvent } from 'react';
import { useTodos } from '../context/TodoContext';

interface InlineAddTodoProps {
  date: Date;
}

const InlineAddTodo: React.FC<InlineAddTodoProps> = ({ date }) => {
  const { createTodo } = useTodos();
  const [text, setText] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async () => {
    if (text.trim() === '') {
      return;
    }

    setIsLoading(true);

    try {
      await createTodo(text, date);
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
        placeholder="Add a todo..."
        disabled={isLoading}
      />

      <div className="todo-actions">
        {/* Empty space to align with other todo items */}
      </div>
    </div>
  );
};

export default InlineAddTodo;
