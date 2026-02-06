import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/date_timeline.dart';
import '../widgets/app_dialogs.dart';
import '../providers/todo_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../models/todo.dart';
import '../services/haptic_service.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({Key? key}) : super(key: key);

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController(initialPage: 1000);
  int _currentPageIndex = 1000;
  final GlobalKey<DateTimelineState> _timelineKey = GlobalKey();
  Todo? _draggedTodo;
  bool _isHoveringTimeline = false;
  double _dragX = 0;
  double _dragY = 0;

  // Completion animation state
  final Set<String> _animatingOutTodoKeys = {};
  final Map<String, AnimationController> _animationControllers = {};

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
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _todoKey(Todo todo) {
    return '${todo.id ?? 'v'}_${todo.recurringTodoId ?? 'n'}_${todo.instanceDate}';
  }

  void _animateCompletion(Todo todo, bool newValue, TodoProvider todoProvider) async {
    final key = _todoKey(todo);
    if (_animatingOutTodoKeys.contains(key)) return;

    final controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _animationControllers[key] = controller;

    setState(() {
      _animatingOutTodoKeys.add(key);
    });

    await controller.forward();
    if (!mounted) return;

    // Call provider while key is still in animating set
    todoProvider.completeTodo(
      todo.id,
      todo.assignedDate,
      newValue,
      isVirtual: todo.isVirtual,
      recurringTodoId: todo.recurringTodoId,
      instanceDate: todo.instanceDate,
    );

    // Wait for rebuild to complete before cleaning up
    await Future.delayed(const Duration(milliseconds: 50));

    _animationControllers.remove(key)?.dispose();
    if (mounted) {
      setState(() {
        _animatingOutTodoKeys.remove(key);
      });
    }
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

    return AppBottomSheet.show(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          String? detectedPattern;

          textController.addListener(() {
            final newPattern = _detectRecurrencePattern(textController.text);
            if (newPattern != detectedPattern) {
              setState(() {
                detectedPattern = newPattern;
              });
            }
          });

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: textController,
                autofocus: true,
                hintText: 'What needs to be done?',
                maxLines: 3,
                textInputAction: TextInputAction.done,
                onSubmitted: (value) {
                  Navigator.of(context).pop();
                  if (value.trim().isNotEmpty) {
                    HapticService.action();
                    todoProvider.createTodo(text: value.trim(), position: position);
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                "Tip: Add 'every day', 'every week', etc.",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
              if (detectedPattern != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue.shade900.withValues(alpha: 0.4) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.blue.shade700 : Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.repeat, size: 18, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Recurring: $detectedPattern',
                        style: TextStyle(
                          color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppCancelButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppActionButton(
                      label: 'Add',
                      onPressed: () {
                        Navigator.of(context).pop();
                        final text = textController.text.trim();
                        if (text.isNotEmpty) {
                          HapticService.action();
                          todoProvider.createTodo(text: text, position: position);
                        }
                      },
                    ),
                  ),
                ],
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
                  HapticService.action();
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
                            return Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
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

                    // Date Timeline
                    DateTimeline(
                      key: _timelineKey,
                      selectedDate: todoProvider.selectedDate,
                      onDateSelected: _navigateToDate,
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
                            color: Theme.of(context).cardColor.withValues(alpha: 0.95),
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
                child: Icon(
                  Icons.add_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
              ),
            );
          },
        ),
        if (todos.isEmpty && !todoProvider.isSelectedDateLoaded)
          SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
            ),
          )
        else ...[
          // Top divider for visual separation from date timeline
          SliverToBoxAdapter(
            child: Divider(
              height: 1,
              thickness: 1,
              indent: 16,
              endIndent: 16,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            ),
          ),

          // Incomplete section
          if (incompleteTodos.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              sliver: SliverReorderableList(
                autoScrollerVelocityScalar: _isHoveringTimeline ? 0.0001 : null,
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
                  HapticService.action();

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
                autoScrollerVelocityScalar: _isHoveringTimeline ? 0.0001 : null,
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
                  HapticService.action();

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
              child: Column(
                children: [
                  const SizedBox(height: 54),
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 54),
                ],
              ),
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
    final key = _todoKey(todo);
    final isAnimatingOut = _animatingOutTodoKeys.contains(key);
    final controller = _animationControllers[key];

    Widget todoWidget = Dismissible(
      key: Key('todo_${todo.id ?? 'v'}_${todo.recurringTodoId ?? 'n'}_${todo.instanceDate}'),
      dismissThresholds: const {
        DismissDirection.endToStart: 0.5,
        DismissDirection.startToEnd: 0.4,
      },
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
          HapticService.action();
          final currentDate = DateTime.parse(todo.assignedDate);
          final nextDay = currentDate.add(const Duration(days: 1));

          await todoProvider.moveTodo(todo, nextDay);
          return false;
        } else {
          // Swipe left - delete
          return await _confirmDelete(todo);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
          onTap: () => _showEditTodoDialog(todo, todoProvider),
          leading: Checkbox(
            value: todo.isCompleted,
            onChanged: (value) {
              if (value != null) {
                HapticService.toggle();
                _animateCompletion(todo, value, todoProvider);
              }
            },
            activeColor: Theme.of(context).colorScheme.primary,
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
                    color: todo.isCompleted
                        ? Colors.grey
                        : Theme.of(context).textTheme.bodyLarge?.color,
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
          Divider(
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ],
      ),
    );

    if (isAnimatingOut && controller != null) {
      return SizeTransition(
        sizeFactor: Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOut),
        ),
        axisAlignment: -1.0,
        child: FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeOut),
          ),
          child: todoWidget,
        ),
      );
    }

    return todoWidget;
  }

  Future<bool> _confirmDelete(Todo todo) async {
    if (todo.recurringTodoId != null) {
      // Show choice dialog for recurring todo
      final result = await AppChoiceDialog.show(
        context: context,
        description: 'This is a recurring todo. What would you like to do?',
        options: [
          const AppChoiceOption(label: 'Delete This Instance', value: 'this'),
          const AppChoiceOption(label: 'Delete All Future', value: 'all', isDestructive: true),
        ],
      );

      if (result == 'this') {
        HapticService.destructive();
        await context.read<TodoProvider>().deleteTodo(
              todo.id,
              todo.assignedDate,
              isVirtual: todo.isVirtual,
              recurringTodoId: todo.recurringTodoId,
              instanceDate: todo.instanceDate,
            );
      } else if (result == 'all') {
        HapticService.destructive();
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
      // Non-recurring: delete immediately, no dialog
      HapticService.destructive();
      await context.read<TodoProvider>().deleteTodo(todo.id, todo.assignedDate);
      return false;
    }
  }

  Future<void> _showEditTodoDialog(Todo todo, TodoProvider todoProvider) async {
    final textController = TextEditingController(text: todo.text);

    return AppBottomSheet.show(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
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

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (todo.recurringTodoId != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.orange.shade900.withValues(alpha: 0.4) : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.orange.shade700 : Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, size: 18, color: isDark ? Colors.orange.shade300 : Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Editing will orphan this from its recurring series',
                          style: TextStyle(
                            color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              AppTextField(
                controller: textController,
                autofocus: true,
                hintText: 'Enter todo text...',
                maxLines: 3,
                textInputAction: TextInputAction.done,
                onSubmitted: (value) {
                  Navigator.of(context).pop();
                  if (value.trim().isNotEmpty && value.trim() != todo.text) {
                    HapticService.action();
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
                    color: isDark ? Colors.blue.shade900.withValues(alpha: 0.4) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.blue.shade700 : Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.repeat, size: 18, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Recurring: $detectedPattern',
                        style: TextStyle(
                          color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppCancelButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppActionButton(
                      label: 'Save',
                      onPressed: () {
                        Navigator.of(context).pop();
                        final text = textController.text.trim();
                        if (text.isNotEmpty && text != todo.text) {
                          HapticService.action();
                          todoProvider.updateTodo(
                            todoId: todo.id,
                            text: text,
                            isVirtual: todo.isVirtual,
                            recurringTodoId: todo.recurringTodoId,
                            instanceDate: todo.instanceDate,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
