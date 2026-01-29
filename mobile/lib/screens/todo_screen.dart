import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  final GlobalKey<DateTimelineState> _timelineKey = GlobalKey();
  Todo? _draggedTodo;
  bool _isHoveringTimeline = false;
  double _dragX = 0;
  double _dragY = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Delay to next event loop to prevent 'childSemantics._needsLayout' assertion
      // when ReorderableListView and DateTimeline are initializing simultaneously.
      await Future.delayed(Duration.zero);
      if (!mounted) return;
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

  Future<void> _showAddTodoDialog({int? position}) async {
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
                      todoProvider.createTodo(text: value.trim(), position: position);
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
                    todoProvider.createTodo(text: text, position: position);
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<TodoProvider>(
        builder: (context, todoProvider, child) {
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerMove: (event) {
              if (_draggedTodo != null) {
                final date = _timelineKey.currentState?.checkDragPosition(event.position);
                final isHovering = date != null;
                
                setState(() {
                  _dragX = event.position.dx;
                  _dragY = event.position.dy;
                  if (_isHoveringTimeline != isHovering) {
                    _isHoveringTimeline = isHovering;
                  }
                });
              }
            },
            onPointerUp: (event) {
              if (_draggedTodo != null) {
                final date = _timelineKey.currentState?.checkDragPosition(event.position);
                _timelineKey.currentState?.clearHover();
                
                if (date != null && date != todoProvider.selectedDate) {
                  // Drop on timeline!
                  final todo = _draggedTodo!;
                  // Reset drag state
                  setState(() {
                    _draggedTodo = null;
                    _isHoveringTimeline = false;
                    _dragX = 0;
                    _dragY = 0;
                  });
                  // Perform move
                  todoProvider.moveTodo(todo, date);
                } else {
                  // Normal drop or cancel
                  setState(() {
                    _draggedTodo = null;
                    _isHoveringTimeline = false;
                    _dragX = 0;
                    _dragY = 0;
                  });
                }
              }
            },
            child: Stack(
              children: [
                Column(
                  children: [
                    // Date Timeline
                    DateTimeline(
                      key: _timelineKey,
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

                    // Main Content Area (Loading / Error / List)
                    Expanded(
                      child: Builder(
                        builder: (context) {
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

                          return GestureDetector(
                            onHorizontalDragEnd: (details) {
                              if (details.primaryVelocity != null) {
                                if (details.primaryVelocity! < 0) {
                                  _goToNextDay();
                                } else if (details.primaryVelocity! > 0) {
                                  _goToPreviousDay();
                                }
                              }
                            },
                            child: _buildTodoList(todoProvider),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                
                // Custom Drag Feedback (Manual Stack)
                if (_isHoveringTimeline && _draggedTodo != null)
                  Positioned(
                    left: _dragX - 50, // Center roughly on finger (assuming ~100 width)
                    top: _dragY - 75,  // Center roughly vertically above finger
                    child: IgnorePointer(
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 1)
                            ],
                          ),
                          child: Text(
                            _draggedTodo?.text ?? '',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_now',
        onPressed: _showAddTodoDialog,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add Todo',
      ),
    );
  }



  Widget _buildTodoList(TodoProvider todoProvider) {
    final todos = todoProvider.selectedDateTodos;

    // Split into incomplete and complete sections
    final incompleteTodos = todos.where((t) => !t.isCompleted).toList();
    final completeTodos = todos.where((t) => t.isCompleted).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () async {
            await _showAddTodoDialog(position: 1);
          },
          builder: (
            BuildContext context,
            RefreshIndicatorMode refreshState,
            double pulledExtent,
            double refreshTriggerPullDistance,
            double refreshIndicatorExtent,
          ) {
            final double percentage = (pulledExtent / refreshTriggerPullDistance).clamp(0.0, 1.0);
            return Center(
              child: Opacity(
                opacity: percentage,
                child: const Icon(
                  Icons.add_circle,
                  color: Colors.green,
                  size: 32,
                ),
              ),
            );
          },
        ),
        if (todos.isEmpty)
          SliverFillRemaining(
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
                  'Tap + (or pull down) to add a new todo',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          )
        else ...[
          // Incomplete section
          if (incompleteTodos.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              sliver: SliverReorderableList(
                onReorderStart: (index) {
                  setState(() {
                    _draggedTodo = incompleteTodos[index];
                  });
                },
                onReorderEnd: (index) {
                  if (_draggedTodo != null && !_isHoveringTimeline) {
                    setState(() {
                      _draggedTodo = null;
                    });
                  }
                },
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      if (_isHoveringTimeline) {
                        return const SizedBox.shrink();
                      }
                      return Material(
                        elevation: 0,
                        color: Colors.transparent,
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                onReorder: (oldIndex, newIndex) {
                  if (_isHoveringTimeline) return;

                  todoProvider.reorderTodos(
                    todoProvider.selectedDate.toString().split(' ')[0],
                    oldIndex,
                    newIndex,
                  );
                },
                itemCount: incompleteTodos.length,
                itemBuilder: (context, index) {
                  final todo = incompleteTodos[index];
                  final item = _buildTodoItem(todo, todoProvider, isReorderable: true);
                  return ReorderableDelayedDragStartListener(
                    key: Key('incomplete_${todo.id ?? 'v'}_${todo.recurringTodoId ?? 'n'}_${todo.instanceDate}'),
                    index: index,
                    child: item,
                  );
                },
              ),
            ),

          // Complete section
          if (completeTodos.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
              sliver: SliverReorderableList(
                onReorderStart: (index) {
                  setState(() {
                    _draggedTodo = completeTodos[index];
                  });
                },
                onReorderEnd: (index) {
                  if (_draggedTodo != null && !_isHoveringTimeline) {
                    setState(() {
                      _draggedTodo = null;
                    });
                  }
                },
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      if (_isHoveringTimeline) {
                        return const SizedBox.shrink();
                      }
                      return Material(
                        elevation: 0,
                        color: Colors.transparent,
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                onReorder: (oldIndex, newIndex) {
                  if (_isHoveringTimeline) return;

                  final offset = incompleteTodos.length;
                  todoProvider.reorderTodos(
                    todoProvider.selectedDate.toString().split(' ')[0],
                    oldIndex + offset,
                    newIndex + offset,
                  );
                },
                itemCount: completeTodos.length,
                itemBuilder: (context, index) {
                  final todo = completeTodos[index];
                  final item = _buildTodoItem(todo, todoProvider, isReorderable: true);
                  return ReorderableDelayedDragStartListener(
                    key: Key('complete_${todo.id ?? 'v'}_${todo.recurringTodoId ?? 'n'}_${todo.instanceDate}'),
                    index: index,
                    child: item,
                  );
                },
              ),
            ),

          // Tappable empty space to add todo at end of incomplete section
          SliverToBoxAdapter(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // Position after last incomplete todo (before completes)
                final position = incompleteTodos.isEmpty ? 1 : incompleteTodos.length + 1;
                _showAddTodoDialog(position: position);
              },
              child: const SizedBox(height: 140), // ~2 todo item heights
            ),
          ),
          // Fill any remaining space
          SliverFillRemaining(
            hasScrollBody: false,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final position = incompleteTodos.isEmpty ? 1 : incompleteTodos.length + 1;
                _showAddTodoDialog(position: position);
              },
              child: Container(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTodoItem(Todo todo, TodoProvider todoProvider, {bool isReorderable = false}) {
    final widget = Dismissible(
      key: Key('todo_${todo.id ?? 'v'}_${todo.recurringTodoId ?? 'n'}_${todo.instanceDate}'),
      background: Container(
        color: Colors.blue,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.arrow_forward, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right - move to next day
          final currentDate = DateTime.parse(todo.assignedDate);
          final nextDay = currentDate.add(const Duration(days: 1));
          
          await todoProvider.moveTodo(todo, nextDay);
          return false; // Don't dismiss immediately, let provider handle list update
        } else {
          // Swipe left - delete
          return await _confirmDelete(todo);
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        elevation: 1,
        child: ListTile(
          onTap: () => _showEditTodoDialog(todo, todoProvider),
          leading: Checkbox(
            value: todo.isCompleted,
            onChanged: (value) {
              if (value != null) {
                todoProvider.completeTodo(
                  todo.id,
                  todo.assignedDate,
                  value,
                  isVirtual: todo.isVirtual,
                  recurringTodoId: todo.recurringTodoId,
                  instanceDate: todo.instanceDate,
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
              if (todo.isVirtual || todo.recurringTodoId != null)
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
        await context.read<TodoProvider>().deleteTodo(
              todo.id,
              todo.assignedDate,
              isVirtual: todo.isVirtual,
              recurringTodoId: todo.recurringTodoId,
              instanceDate: todo.instanceDate,
            );
      } else if (result == 'all') {
        await context.read<TodoProvider>().deleteTodo(
              todo.id,
              todo.assignedDate,
              isVirtual: todo.isVirtual,
              recurringTodoId: todo.recurringTodoId,
              instanceDate: todo.instanceDate,
              deleteAllFuture: true,
            );
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
      if (result ?? false) {
        await context.read<TodoProvider>().deleteTodo(todo.id, todo.assignedDate);
      }
      return false;
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
                      todoId: todo.id,
                      text: text,
                      isVirtual: todo.isVirtual,
                      recurringTodoId: todo.recurringTodoId,
                      instanceDate: todo.instanceDate,
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
