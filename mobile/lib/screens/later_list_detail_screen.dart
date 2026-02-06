import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../widgets/app_dialogs.dart';
import '../providers/later_list_provider.dart';
import '../models/later_list.dart';
import '../models/later_list_todo.dart';
import '../services/haptic_service.dart';

class LaterListDetailScreen extends StatefulWidget {
  final LaterList list;

  const LaterListDetailScreen({Key? key, required this.list}) : super(key: key);

  @override
  State<LaterListDetailScreen> createState() => _LaterListDetailScreenState();
}

class _LaterListDetailScreenState extends State<LaterListDetailScreen> with TickerProviderStateMixin {
  // Completion animation state
  final Set<int> _animatingOutTodoIds = {};
  final Map<int, AnimationController> _animationControllers = {};

  @override
  void dispose() {
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _animateCompletion(LaterListTodo todo, bool newValue, LaterListProvider provider) async {
    if (_animatingOutTodoIds.contains(todo.id)) return;

    final controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _animationControllers[todo.id] = controller;

    setState(() {
      _animatingOutTodoIds.add(todo.id);
    });

    await controller.forward();
    if (!mounted) return;

    // Call provider while id is still in animating set
    if (newValue) {
      provider.completeTodo(widget.list.id, todo.id);
    } else {
      provider.uncompleteTodo(widget.list.id, todo.id);
    }

    // Wait for rebuild to complete before cleaning up
    await Future.delayed(const Duration(milliseconds: 50));

    _animationControllers.remove(todo.id)?.dispose();
    if (mounted) {
      setState(() {
        _animatingOutTodoIds.remove(todo.id);
      });
    }
  }

  Future<void> _showAddTodoDialog({int? position}) async {
    final textController = TextEditingController();
    final provider = context.read<LaterListProvider>();

    return AppBottomSheet.show(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: textController,
            autofocus: true,
            hintText: 'Enter item text...',
            maxLength: 500,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              Navigator.of(context).pop();
              if (value.trim().isNotEmpty) {
                HapticService.action();
                provider.createTodo(widget.list.id, value.trim(), position: position);
              }
            },
          ),
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
                      provider.createTodo(widget.list.id, text, position: position);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEditTodoDialog(LaterListTodo todo) async {
    final textController = TextEditingController(text: todo.text);
    final provider = context.read<LaterListProvider>();

    return AppBottomSheet.show(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: textController,
            autofocus: true,
            hintText: 'Enter item text...',
            maxLength: 500,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              Navigator.of(context).pop();
              if (value.trim().isNotEmpty && value.trim() != todo.text) {
                HapticService.action();
                provider.updateTodoText(widget.list.id, todo.id, value.trim());
              }
            },
          ),
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
                      provider.updateTodoText(widget.list.id, todo.id, text);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar removed to allow MainNavigation AppBar to take precedence
      body: Consumer<LaterListProvider>(
        builder: (context, provider, child) {
          final todos = provider.getTodosForList(widget.list.id);

          return Column(
            children: [
              // Error banner
              if (provider.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.red.shade100,
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: provider.clearError,
                        color: Colors.red.shade700,
                      ),
                    ],
                  ),
                ),

              // Main content
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (provider.isLoading && todos.isEmpty) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                        ),
                      );
                    }

                    return CustomScrollView(
                      slivers: [
                        // Pull-down-to-add gesture
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
                        // Reorderable list items
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          sliver: SliverReorderableList(
                            itemCount: todos.length,
                            onReorder: (oldIndex, newIndex) {
                              if (oldIndex < newIndex) {
                                newIndex -= 1;
                              }
                              HapticService.action();
                              final todo = todos[oldIndex];
                              provider.updateTodoPosition(widget.list.id, todo.id, newIndex);
                            },
                            itemBuilder: (context, index) {
                              final todo = todos[index];
                              return ReorderableDragStartListener(
                                key: Key('todo_${todo.id}'),
                                index: index,
                                child: _buildTodoItem(todo, provider),
                              );
                            },
                          ),
                        ),
                        // Tappable empty space at bottom
                        SliverToBoxAdapter(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _showAddTodoDialog,
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
                        // Fill remaining space
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _showAddTodoDialog,
                            child: Container(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTodoItem(LaterListTodo todo, LaterListProvider provider) {
    final isAnimatingOut = _animatingOutTodoIds.contains(todo.id);
    final controller = _animationControllers[todo.id];

    Widget todoWidget = Material(
      type: MaterialType.transparency,
      child: Dismissible(
        key: Key('dismissible_${todo.id}'),
        dismissThresholds: const {DismissDirection.endToStart: 0.5},
        background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          return await _confirmDeleteDismiss(todo);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              onTap: () => _showEditTodoDialog(todo),
              leading: Checkbox(
                value: todo.isCompleted,
                onChanged: (value) {
                  if (value != null) {
                    HapticService.toggle();
                    _animateCompletion(todo, value, provider);
                  }
                },
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                todo.text,
                style: TextStyle(
                  fontSize: 16,
                  decoration: todo.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                  color: todo.isCompleted
                      ? Colors.grey
                      : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              indent: 8,
              endIndent: 8,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            ),
          ],
        ),
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

  Future<bool> _confirmDeleteDismiss(LaterListTodo todo) async {
    HapticService.destructive();
    final provider = context.read<LaterListProvider>();
    provider.deleteTodo(widget.list.id, todo.id);
    return false;
  }
}
