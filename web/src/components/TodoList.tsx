import React, { useState, useCallback } from 'react';
import { DndProvider, useDrag, useDrop } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import type { Todo } from '../types';
import { useTodos } from '../context/TodoContext';
import TodoItem from './TodoItem';

const ITEM_TYPE = 'TODO';

interface DraggableTodoItemProps {
  todo: Todo;
  index: number;
  onMove: (dragIndex: number, hoverIndex: number) => void;
  onDrop: (todoId: number, newPosition: number, isVirtual: boolean, recurringTodoId: number | null, instanceDate: string) => void;
}

const DraggableTodoItem: React.FC<DraggableTodoItemProps> = ({ todo, index, onMove, onDrop }) => {
  const { deleteTodo } = useTodos();
  const [isDeleting, setIsDeleting] = useState(false);

  const [{ isDragging }, drag] = useDrag({
    type: ITEM_TYPE,
    item: { todo, index },
    collect: (monitor) => ({
      isDragging: monitor.isDragging(),
    }),
    end: (item, monitor) => {
      if (monitor.didDrop()) {
        // Calculate new position based on final index
        onDrop(item.todo.id!, index, item.todo.isVirtual, item.todo.recurringTodoId, item.todo.instanceDate);
      }
    },
  });

  const [, drop] = useDrop({
    accept: ITEM_TYPE,
    hover: (draggedItem: { todo: Todo; index: number }) => {
      if (draggedItem.index !== index) {
        onMove(draggedItem.index, index);
        draggedItem.index = index;
      }
    },
  });

  const handleDelete = async (deleteAllFuture?: boolean) => {
    if (isDeleting) return;

    setIsDeleting(true);
    try {
      await deleteTodo(
        todo.id!,
        todo.isVirtual,
        todo.recurringTodoId,
        todo.instanceDate,
        deleteAllFuture
      );
    } catch (err) {
      console.error('Failed to delete todo:', err);
    } finally {
      setIsDeleting(false);
    }
  };

  return (
    <div
      ref={(node) => {
        drag(drop(node));
      }}
      style={{
        opacity: isDragging ? 0.5 : 1,
        cursor: 'move',
      }}
    >
      <TodoItem todo={todo} onDelete={handleDelete} />
    </div>
  );
};

interface TodoListProps {
  todos: Todo[];
  date: string;
}

const TodoList: React.FC<TodoListProps> = ({ todos: initialTodos }) => {
  const { updateTodoPosition } = useTodos();
  const [todos, setTodos] = useState<Todo[]>(initialTodos);

  // Update local state when props change
  React.useEffect(() => {
    setTodos(initialTodos);
  }, [initialTodos]);

  const moveTodo = useCallback((dragIndex: number, hoverIndex: number) => {
    setTodos((prevTodos) => {
      const newTodos = [...prevTodos];
      const [draggedTodo] = newTodos.splice(dragIndex, 1);
      newTodos.splice(hoverIndex, 0, draggedTodo);
      return newTodos;
    });
  }, []);

  const handleDrop = async (
    todoId: number,
    newPosition: number,
    isVirtual: boolean,
    recurringTodoId: number | null,
    instanceDate: string
  ) => {
    try {
      await updateTodoPosition(todoId, newPosition, isVirtual, recurringTodoId, instanceDate);
    } catch (err) {
      console.error('Failed to update todo position:', err);
      // Revert to initial state on error
      setTodos(initialTodos);
    }
  };

  if (todos.length === 0) {
    return (
      <div className="todo-list-empty">
        <p>No todos for this date. Add one above!</p>
      </div>
    );
  }

  // Sort todos by position
  const sortedTodos = [...todos].sort((a, b) => a.position - b.position);

  return (
    <DndProvider backend={HTML5Backend}>
      <div className="todo-list">
        {sortedTodos.map((todo, index) => (
          <DraggableTodoItem
            key={todo.id || `virtual-${todo.recurringTodoId}-${todo.instanceDate}`}
            todo={todo}
            index={index}
            onMove={moveTodo}
            onDrop={handleDrop}
          />
        ))}
      </div>
    </DndProvider>
  );
};

export default TodoList;
