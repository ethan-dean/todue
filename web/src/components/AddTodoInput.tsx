import React, { useState, type KeyboardEvent } from 'react';
import { useTodos } from '../context/TodoContext';

interface AddTodoInputProps {
  date: Date;
}

const AddTodoInput: React.FC<AddTodoInputProps> = ({ date }) => {
  const { createTodo } = useTodos();
  const [text, setText] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async () => {
    if (text.trim() === '') {
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      await createTodo(text, date);
      setText('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create todo');
    } finally {
      setIsLoading(false);
    }
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      handleSubmit();
    } else if (e.key === 'Escape') {
      setText('');
      setError(null);
    }
  };

  return (
    <div className="add-todo-input-container">
      <div className="add-todo-input">
        <input
          type="text"
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Add a new todo... (e.g., 'mow lawn every week')"
          disabled={isLoading}
          className="todo-input"
        />
        <button
          onClick={handleSubmit}
          disabled={isLoading || text.trim() === ''}
          className="btn-add"
        >
          {isLoading ? 'Adding...' : 'Add'}
        </button>
      </div>
      {error && (
        <div className="error-message" role="alert">
          {error}
        </div>
      )}
      <div className="add-todo-hint">
        <small>
          Tip: Include "every day", "every week", "every other week", "every month", or "every year" to create a recurring todo
        </small>
      </div>
    </div>
  );
};

export default AddTodoInput;
