import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../widgets/date_timeline.dart';
import '../providers/todo_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../models/todo.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({Key? key}) : super(key: key);

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final PageController _pageController = PageController(initialPage: 1000);
  int _currentPageIndex = 1000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final todoProvider = context.read<TodoProvider>();
      todoProvider.loadTodos(force: true);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToDate(DateTime date) {
    final todoProvider = context.read<TodoProvider>();
    todoProvider.selectDate(date);
  }

  void _goToPreviousDay() {
    final todoProvider = context.read<TodoProvider>();
    final previousDay = todoProvider.selectedDate.subtract(const Duration(days: 1));
    todoProvider.selectDate(previousDay);
  }

  void _goToNextDay() {
    final todoProvider = context.read<TodoProvider>();
    final nextDay = todoProvider.selectedDate.add(const Duration(days: 1));
    todoProvider.selectDate(nextDay);
  }

  void _goToToday() {
    final todoProvider = context.read<TodoProvider>();
    todoProvider.selectDate(DateTime.now());
  }

  String? _detectRecurrencePattern(String text) {
    final lowerText = text.toLowerCase();
    if (lowerText.contains('every day')) return 'Daily';
    if (lowerText.contains('every week')) return 'Weekly';
    if (lowerText.contains('every other week') || lowerText.contains('every 2 weeks')) return 'Biweekly';
    if (lowerText.contains('every month')) return 'Monthly';
    if (lowerText.contains('every year')) return 'Yearly';
    return null;
  }

  Future<void> _showAddTodoDialog() async {
    final textController = TextEditingController();
    final todoProvider = context.read<TodoProvider>();

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          String? detectedPattern;

          textController.addListener(() {
            final newPattern = _detectRecurrencePattern(textController.text);
            if (newPattern != detectedPattern) {
              setState(() {
                detectedPattern = newPattern;
              });
            }
          });

          return AlertDialog(
            title: const Text('Add Todo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: textController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Enter todo text...',
                    helperText: 'Tip: Add "every day", "every week", etc.',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      Navigator.of(context).pop();
                      todoProvider.createTodo(text: value.trim());
                    }
                  },
                ),
                if (detectedPattern != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.repeat, size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Recurring: $detectedPattern',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final text = textController.text.trim();
                  if (text.isNotEmpty) {
                    Navigator.of(context).pop();
                    todoProvider.createTodo(text: text);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleLogout() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) {
      return 'Today, ${DateFormat('MMM d').format(date)}';
    } else if (targetDate == yesterday) {
      return 'Yesterday, ${DateFormat('MMM d').format(date)}';
    } else if (targetDate == tomorrow) {
      return 'Tomorrow, ${DateFormat('MMM d').format(date)}';
    } else {
      return DateFormat('EEEE, MMM d, y').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todue'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () {
                  themeProvider.toggleTheme();
                },
                tooltip: isDark ? 'Light Mode' : 'Dark Mode',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _goToToday,
            tooltip: 'Today',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<TodoProvider>().refresh();
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Consumer<TodoProvider>(
        builder: (context, todoProvider, child) {
          if (todoProvider.isLoading && todoProvider.selectedDateTodos.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            );
          }

          if (todoProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${todoProvider.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => todoProvider.refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Date Timeline
              DateTimeline(
                selectedDate: todoProvider.selectedDate,
                onDateSelected: _navigateToDate,
              ),

              // Offline indicator
              if (!todoProvider.isOnline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.orange.shade100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 16, color: Colors.orange.shade900),
                      const SizedBox(width: 8),
                      Text(
                        'Offline Mode',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // Todo List
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity != null) {
                      if (details.primaryVelocity! < 0) {
                        // Swiped left - go to next day
                        _goToNextDay();
                      } else if (details.primaryVelocity! > 0) {
                        // Swiped right - go to previous day
                        _goToPreviousDay();
                      }
                    }
                  },
                  child: RefreshIndicator(
                    onRefresh: () => todoProvider.refresh(),
                    color: Colors.green,
                    child: _buildTodoList(todoProvider),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTodoDialog,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add Todo',
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildTodoList(TodoProvider todoProvider) {
    final todos = todoProvider.selectedDateTodos;

    if (todos.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No todos for this day',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + to add a new todo',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ReorderableListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      onReorder: (oldIndex, newIndex) {
        // Call the provider to update on backend
        // We don't await here to keep UI responsive, provider handles optimistic update
        todoProvider.reorderTodos(
          todoProvider.selectedDate.toString().split(' ')[0],
          oldIndex,
          newIndex,
        );
      },
      children: todos.map((todo) {
        return _buildTodoItem(todo, todoProvider, isReorderable: true);
      }).toList(),
    );
  }

  Widget _buildTodoItem(Todo todo, TodoProvider todoProvider, {bool isReorderable = false}) {
    final widget = Dismissible(
      key: Key('todo_${todo.id}_${todo.instanceDate}'),
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right - complete/uncomplete
          await todoProvider.completeTodo(
            todo.id!,
            todo.assignedDate,
            !todo.isCompleted,
          );
          return false;
        } else {
          // Swipe left - delete
          return await _confirmDelete(todo);
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        elevation: 1,
        child: ListTile(
          leading: Checkbox(
            value: todo.isCompleted,
            onChanged: (value) {
              if (value != null) {
                todoProvider.completeTodo(
                  todo.id!,
                  todo.assignedDate,
                  value,
                );
              }
            },
            activeColor: Colors.green,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  todo.text,
                  style: TextStyle(
                    fontSize: 16,
                    decoration: todo.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: todo.isCompleted ? Colors.grey : Colors.black,
                  ),
                ),
              ),
              if (todo.isVirtual)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.repeat,
                    size: 14,
                    color: Colors.blue.shade700,
                  ),
                ),
              if (todo.isRolledOver)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.history,
                    size: 14,
                    color: Colors.orange.shade700,
                  ),
                ),
            ],
          ),
          subtitle: null,
          trailing: PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                _showEditTodoDialog(todo, todoProvider);
              } else if (value == 'delete') {
                final confirmed = await _confirmDelete(todo);
                if (confirmed) {
                  todoProvider.deleteTodo(todo.id!, todo.assignedDate);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return widget;
  }

  Future<bool> _confirmDelete(Todo todo) async {
    if (todo.recurringTodoId != null) {
      // Show options for recurring todo
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Recurring Todo'),
          content: const Text(
            'This is a recurring todo. What would you like to do?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('this'),
              child: const Text('Delete This Instance'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('all'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete All Future'),
            ),
          ],
        ),
      );

      if (result == 'this') {
        await context.read<TodoProvider>().deleteTodo(todo.id!, todo.assignedDate);
        return false; // Don't dismiss, we already handled it
      } else if (result == 'all') {
        // TODO: Implement delete all future
        await context.read<TodoProvider>().deleteTodo(todo.id!, todo.assignedDate);
        return false;
      }
      return false;
    } else {
      // Simple confirmation for non-recurring todo
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Todo'),
          content: const Text('Are you sure you want to delete this todo?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      return result ?? false;
    }
  }

  Future<void> _showEditTodoDialog(Todo todo, TodoProvider todoProvider) async {
    final textController = TextEditingController(text: todo.text);

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          String? detectedPattern;

          textController.addListener(() {
            final newPattern = _detectRecurrencePattern(textController.text);
            if (newPattern != detectedPattern) {
              setState(() {
                detectedPattern = newPattern;
              });
            }
          });

          // Initial pattern detection
          detectedPattern = _detectRecurrencePattern(textController.text);

          return AlertDialog(
            title: const Text('Edit Todo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (todo.recurringTodoId != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, size: 18, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Editing will orphan this from its recurring series',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: textController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Enter todo text...',
                    helperText: detectedPattern != null
                      ? 'Note: This will create a new recurring series'
                      : 'Tip: Add "every day", "every week", etc.',
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty && value.trim() != todo.text) {
                      Navigator.of(context).pop();
                      todoProvider.updateTodo(
                        todoId: todo.id!,
                        text: value.trim(),
                      );
                    }
                  },
                ),
                if (detectedPattern != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.repeat, size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Recurring: $detectedPattern',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final text = textController.text.trim();
                  if (text.isNotEmpty && text != todo.text) {
                    Navigator.of(context).pop();
                    todoProvider.updateTodo(
                      todoId: todo.id!,
                      text: text,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
