import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../widgets/app_dialogs.dart';
import '../providers/later_list_provider.dart';
import '../models/later_list.dart';
import '../models/later_list_todo.dart';

class LaterListDetailScreen extends StatefulWidget {
  final LaterList list;

  const LaterListDetailScreen({Key? key, required this.list}) : super(key: key);

  @override
  State<LaterListDetailScreen> createState() => _LaterListDetailScreenState();
}

class _LaterListDetailScreenState extends State<LaterListDetailScreen> {
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

                    if (todos.isEmpty) {
                      return Center(
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
                              'No items yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add an item',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
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
                            child: const SizedBox(height: 140),
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
    return Material(
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
                    if (value) {
                      provider.completeTodo(widget.list.id, todo.id);
                    } else {
                      provider.uncompleteTodo(widget.list.id, todo.id);
                    }
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
  }

  Future<bool> _confirmDeleteDismiss(LaterListTodo todo) async {
    final provider = context.read<LaterListProvider>();
    provider.deleteTodo(widget.list.id, todo.id);
    return false;
  }
}
