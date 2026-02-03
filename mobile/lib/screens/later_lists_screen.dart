import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
                provider.setCurrentListId(newList.id);
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
                  provider.setCurrentListId(newList.id);
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

  Future<bool> _confirmDeleteDismiss(LaterList list) async {
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
    return false; // Don't dismiss, let provider handle it
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LaterListProvider>(
      builder: (context, provider, child) {
        Widget content;
        
        // If a list is selected, show the detail view
        if (provider.currentListId != null) {
          final selectedList = provider.lists.where((l) => l.id == provider.currentListId).firstOrNull;
          
          if (selectedList != null) {
            content = PopScope(
              key: ValueKey('detail_${selectedList.id}'),
              canPop: false,
              onPopInvoked: (didPop) {
                if (didPop) return;
                provider.setCurrentListId(null);
              },
              child: LaterListDetailScreen(list: selectedList),
            );
          } else {
            // List might have been deleted
            WidgetsBinding.instance.addPostFrameCallback((_) {
              provider.setCurrentListId(null);
            });
            content = const SizedBox.shrink(key: ValueKey('empty'));
          }
        } else {
          // Otherwise show the list of lists
          content = Scaffold(
            key: const ValueKey('list'),
            body: Column(
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

                      return CustomScrollView(
                        slivers: [
                          // Pull-down-to-add gesture
                          CupertinoSliverRefreshControl(
                            onRefresh: () async {
                              await _showCreateListDialog();
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
                          // List items
                          SliverPadding(
                            padding: const EdgeInsets.all(8),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final list = provider.lists[index];
                                  return _buildListItem(list);
                                },
                                childCount: provider.lists.length,
                              ),
                            ),
                          ),
                          // Tappable empty space at bottom
                          SliverToBoxAdapter(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _showCreateListDialog,
                              child: const SizedBox(height: 140),
                            ),
                          ),
                          // Fill remaining space
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _showCreateListDialog,
                              child: Container(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (Widget child, Animation<double> animation) {
            final key = child.key;
            bool isDetail = false;
            if (key is ValueKey<String>) {
              isDetail = key.value.startsWith('detail');
            }
            
            final offset = isDetail ? const Offset(1, 0) : const Offset(-1, 0);
            
            return SlideTransition(
              position: Tween<Offset>(
                begin: offset,
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
          child: content,
        );
      },
    );
  }

  Widget _buildListItem(LaterList list) {
    return Dismissible(
      key: Key('list_${list.id}'),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await _confirmDeleteDismiss(list);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            onTap: () => context.read<LaterListProvider>().setCurrentListId(list.id),
            title: Text(
              list.listName,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge?.color,
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
    );
  }
}
