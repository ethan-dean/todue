import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../widgets/app_dialogs.dart';
import '../providers/later_list_provider.dart';
import '../models/later_list.dart';
import '../services/haptic_service.dart';
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

    return AppBottomSheet.show(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: textController,
            autofocus: true,
            hintText: 'e.g., Movies to Watch',
            maxLength: 100,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) async {
              Navigator.of(context).pop();
              if (value.trim().isNotEmpty) {
                HapticService.action();
                final newList = await provider.createList(value.trim());
                if (newList != null && mounted) {
                  provider.setCurrentListId(newList.id);
                }
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
                  label: 'Create',
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final text = textController.text.trim();
                    if (text.isNotEmpty) {
                      HapticService.action();
                      final newList = await provider.createList(text);
                      if (newList != null && mounted) {
                        provider.setCurrentListId(newList.id);
                      }
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

  Future<bool> _confirmDeleteDismiss(LaterList list) async {
    HapticService.destructive();
    final provider = context.read<LaterListProvider>();
    provider.deleteList(list.id);
    return false;
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
                                  child: Icon(
                                    Icons.add_circle,
                                    color: Theme.of(context).colorScheme.primary,
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
                              child: Column(
                                children: [
                                  const SizedBox(height: 46),
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    indent: 16,
                                    endIndent: 16,
                                    color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 46),
                                ],
                              ),
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
      dismissThresholds: const {DismissDirection.endToStart: 0.5},
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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.read<LaterListProvider>().setCurrentListId(list.id),
            child: ListTile(
              title: Text(
                list.listName,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
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
