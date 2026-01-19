import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LaterListProvider>().setCurrentListId(widget.list.id);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LaterListProvider>().setCurrentListId(null);
      }
    });
    super.dispose();
  }

  Future<void> _showAddTodoDialog() async {
    final textController = TextEditingController();
    final provider = context.read<LaterListProvider>();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter item text...',
            border: OutlineInputBorder(),
          ),
          maxLength: 500,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(context).pop();
              provider.createTodo(widget.list.id, value.trim());
            }
          },
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
                provider.createTodo(widget.list.id, text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditTodoDialog(LaterListTodo todo) async {
    final textController = TextEditingController(text: todo.text);
    final provider = context.read<LaterListProvider>();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter item text...',
            border: OutlineInputBorder(),
          ),
          maxLength: 500,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty && value.trim() != todo.text) {
              Navigator.of(context).pop();
              provider.updateTodoText(widget.list.id, todo.id, value.trim());
            } else {
              Navigator.of(context).pop();
            }
          },
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
                provider.updateTodoText(widget.list.id, todo.id, text);
              } else {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(LaterListTodo todo) async {
    final provider = context.read<LaterListProvider>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
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

    if (result == true) {
      provider.deleteTodo(widget.list.id, todo.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.list.listName),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
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
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
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

                    return RefreshIndicator(
                      onRefresh: () => provider.loadTodosForList(widget.list.id),
                      color: Colors.green,
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
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
                          return _buildTodoItem(todo, provider, key: Key('todo_${todo.id}'));
                        },
                      ),
                    );
                  },
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
        tooltip: 'Add Item',
      ),
    );
  }

  Widget _buildTodoItem(LaterListTodo todo, LaterListProvider provider, {Key? key}) {
    return Dismissible(
      key: key ?? Key('todo_${todo.id}'),
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
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
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
            activeColor: Colors.green,
          ),
          title: Text(
            todo.text,
            style: TextStyle(
              fontSize: 16,
              decoration: todo.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
              color: todo.isCompleted ? Colors.grey : null,
            ),
          ),
          trailing: ReorderableDragStartListener(
            index: 0, // Will be overridden by ReorderableListView
            child: const Icon(Icons.drag_handle, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteDismiss(LaterListTodo todo) async {
    final provider = context.read<LaterListProvider>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
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

    if (result == true) {
      provider.deleteTodo(widget.list.id, todo.id);
    }
    return false; // Don't dismiss, let provider handle it
  }
}
