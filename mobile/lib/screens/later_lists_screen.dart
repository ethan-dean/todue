import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/later_list_provider.dart';
import '../models/later_list.dart';
import 'later_list_detail_screen.dart';

class LaterListsScreen extends StatefulWidget {
  const LaterListsScreen({Key? key}) : super(key: key);

  @override
  State<LaterListsScreen> createState() => _LaterListsScreenState();
}

class _LaterListsScreenState extends State<LaterListsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LaterListProvider>().loadLists();
    });
  }

  Future<void> _showCreateListDialog() async {
    final textController = TextEditingController();
    final provider = context.read<LaterListProvider>();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New List'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g., Movies to Watch',
            border: OutlineInputBorder(),
          ),
          maxLength: 100,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) async {
            if (value.trim().isNotEmpty) {
              Navigator.of(context).pop();
              final newList = await provider.createList(value.trim());
              if (newList != null && mounted) {
                _navigateToListDetail(newList);
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(context).pop();
                final newList = await provider.createList(text);
                if (newList != null && mounted) {
                  _navigateToListDetail(newList);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _navigateToListDetail(LaterList list) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LaterListDetailScreen(list: list),
      ),
    );
  }

  Future<void> _showRenameDialog(LaterList list) async {
    final textController = TextEditingController(text: list.listName);
    final provider = context.read<LaterListProvider>();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename List'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'List name',
            border: OutlineInputBorder(),
          ),
          maxLength: 100,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty && value.trim() != list.listName) {
              Navigator.of(context).pop();
              provider.updateListName(list.id, value.trim());
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
              if (text.isNotEmpty && text != list.listName) {
                Navigator.of(context).pop();
                provider.updateListName(list.id, text);
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

  Future<void> _confirmDelete(LaterList list) async {
    final provider = context.read<LaterListProvider>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List'),
        content: Text(
          'Are you sure you want to delete "${list.listName}"? This will delete all items in this list.',
        ),
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
      provider.deleteList(list.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<LaterListProvider>(
        builder: (context, provider, child) {
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
                    if (provider.isLoading && provider.lists.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      );
                    }

                    if (provider.lists.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.list_alt,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No lists yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to create a new list',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _showCreateListDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Create Your First List'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () => provider.loadLists(),
                      color: Colors.green,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: provider.lists.length,
                        itemBuilder: (context, index) {
                          final list = provider.lists[index];
                          return _buildListItem(list);
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
        onPressed: _showCreateListDialog,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Create List',
      ),
    );
  }

  Widget _buildListItem(LaterList list) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => _navigateToListDetail(list),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.list,
            color: Colors.green.shade700,
          ),
        ),
        title: Text(
          list.listName,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'rename') {
              _showRenameDialog(list);
            } else if (value == 'delete') {
              _confirmDelete(list);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Rename'),
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
    );
  }
}
