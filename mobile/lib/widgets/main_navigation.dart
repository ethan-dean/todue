import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/todo_screen.dart';
import '../screens/later_lists_screen.dart';
import '../screens/routines_screen.dart';
import '../screens/routine_execution_screen.dart';
import '../screens/settings_screen.dart';
import '../providers/later_list_provider.dart';
import '../providers/todo_provider.dart';
import '../providers/routine_provider.dart';
import '../models/routine.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  bool _promptDialogShown = false;

  Future<void> _showPromptDialog(List<PendingRoutinePrompt> prompts) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _RoutinePromptDialog(
        prompts: prompts,
        onStart: (routineId) async {
          Navigator.of(dialogContext).pop();
          final provider = context.read<RoutineProvider>();
          final completion = await provider.startRoutine(routineId);
          if (completion != null && mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RoutineExecutionScreen(routineId: routineId),
              ),
            );
          }
        },
        onAlreadyDone: (routineId) async {
          final provider = context.read<RoutineProvider>();
          await provider.quickCompleteRoutine(routineId);
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        },
        onPartiallyDone: (routineId) async {
          Navigator.of(dialogContext).pop();
          final submitted = await _showPartialCompleteDialog(routineId);
          if (!submitted && mounted) {
            final p = context.read<RoutineProvider>();
            if (p.pendingPrompts.isNotEmpty) {
              _showPromptDialog(p.pendingPrompts);
            }
          }
        },
        onDismiss: (routineId) async {
          final provider = context.read<RoutineProvider>();
          await provider.dismissPrompt(routineId);
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        },
        onClose: () {
          Navigator.of(dialogContext).pop();
        },
      ),
    );
    // Only allow re-showing if prompts are now empty (fully handled)
    if (mounted) {
      final provider = context.read<RoutineProvider>();
      if (provider.pendingPrompts.isEmpty) {
        _promptDialogShown = false;
      }
    }
  }

  Future<bool> _showPartialCompleteDialog(int routineId) async {
    final provider = context.read<RoutineProvider>();

    // Load detail if not cached
    if (provider.getRoutineDetail(routineId) == null) {
      await provider.loadRoutineDetail(routineId);
    }

    final detail = provider.getRoutineDetail(routineId);
    if (detail == null || !mounted) return false;

    final steps = List<RoutineStep>.from(detail.steps)
      ..sort((a, b) => a.position.compareTo(b.position));
    final checkedStepIds = Set<int>.from(steps.map((s) => s.id));

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _PartialCompleteDialog(
        routineName: detail.name,
        steps: steps,
        initialCheckedIds: checkedStepIds,
        onSubmit: (completedIds) async {
          Navigator.of(dialogContext).pop(true);
          await provider.quickCompleteRoutine(routineId, completedStepIds: completedIds.toList());
        },
        onCancel: () {
          Navigator.of(dialogContext).pop(false);
        },
      ),
    );
    return result == true;
  }

  void _onItemTapped(int index) {
    if (index == 1 && _selectedIndex == 1) {
      // User tapped "Later" while on "Later" - go back to list view
      context.read<LaterListProvider>().setCurrentListId(null);
    } else if (index == 0 && _selectedIndex == 0) {
      // User tapped "Now" while on "Now" - go back to today
      context.read<TodoProvider>().selectDate(DateTime.now());
    } else if (index == 2 && _selectedIndex == 2) {
      // User tapped "Routines" while on "Routines" - go back to list view
      context.read<RoutineProvider>().setCurrentRoutineId(null);
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _editRoutineName(int routineId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Routine name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty && mounted) {
      await context
          .read<RoutineProvider>()
          .updateRoutineName(routineId, result.trim());
    }
  }

  Future<void> _editLaterListName(int listId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'List name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty && mounted) {
      await context
          .read<LaterListProvider>()
          .updateListName(listId, result.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LaterListProvider, RoutineProvider>(
      builder: (context, laterListProvider, routineProvider, _) {
        // Check for pending prompts whenever the provider updates
        if (routineProvider.pendingPrompts.isNotEmpty && !_promptDialogShown) {
          _promptDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && routineProvider.pendingPrompts.isNotEmpty) {
              _showPromptDialog(routineProvider.pendingPrompts);
            } else {
              _promptDialogShown = false;
            }
          });
        } else if (routineProvider.pendingPrompts.isEmpty) {
          _promptDialogShown = false;
        }
        String title;
        if (_selectedIndex == 0) {
          title = 'Now';
        } else if (_selectedIndex == 1) {
          // Check if we are viewing a specific list
          if (laterListProvider.currentListId != null) {
            final list = laterListProvider.lists
                .where((l) => l.id == laterListProvider.currentListId)
                .firstOrNull;
            title = list?.listName ?? 'Later';
          } else {
            title = 'Later';
          }
        } else {
          // Routines tab
          if (routineProvider.currentRoutineId != null) {
            final routine = routineProvider.routines
                .where((r) => r.id == routineProvider.currentRoutineId)
                .firstOrNull;
            title = routine?.name ?? 'Routines';
          } else {
            title = 'Routines';
          }
        }

        final bool isLaterListDetail = _selectedIndex == 1 && laterListProvider.currentListId != null;
        final bool isRoutineDetail = _selectedIndex == 2 && routineProvider.currentRoutineId != null;

        Widget titleWidget;
        if (isLaterListDetail) {
          final listId = laterListProvider.currentListId!;
          titleWidget = GestureDetector(
            onTap: () => _editLaterListName(listId, title),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 16),
              ],
            ),
          );
        } else if (isRoutineDetail) {
          final routineId = routineProvider.currentRoutineId!;
          titleWidget = GestureDetector(
            onTap: () => _editRoutineName(routineId, title),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 16),
              ],
            ),
          );
        } else {
          titleWidget = Text(title);
        }

        return Scaffold(
          appBar: AppBar(
            title: titleWidget,
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            actions: [
              if (isRoutineDetail)
                IconButton(
                  icon: Icon(
                    routineProvider.showAnalytics ? Icons.list_alt : Icons.bar_chart,
                  ),
                  onPressed: () {
                    routineProvider.toggleShowAnalytics();
                  },
                  tooltip: routineProvider.showAnalytics ? 'Steps' : 'Analytics',
                ),
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                tooltip: 'Settings',
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: const [
              TodoScreen(),
              LaterListsScreen(),
              RoutinesScreen(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: Colors.green,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.today),
                label: 'Now',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list_alt),
                label: 'Later',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.repeat),
                label: 'Routines',
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==================== Routine Prompt Dialog ====================

class _RoutinePromptDialog extends StatelessWidget {
  final List<PendingRoutinePrompt> prompts;
  final Future<void> Function(int routineId) onStart;
  final Future<void> Function(int routineId) onAlreadyDone;
  final Future<void> Function(int routineId) onPartiallyDone;
  final Future<void> Function(int routineId) onDismiss;
  final VoidCallback onClose;

  const _RoutinePromptDialog({
    required this.prompts,
    required this.onStart,
    required this.onAlreadyDone,
    required this.onPartiallyDone,
    required this.onDismiss,
    required this.onClose,
  });

  String _formatTime(String? time) {
    if (time == null) return '';
    final parts = time.split(':');
    if (parts.length < 2) return time;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = parts[1];
    final ampm = hours >= 12 ? 'PM' : 'AM';
    final hour12 = hours % 12 == 0 ? 12 : hours % 12;
    return '$hour12:$minutes $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Time for Your Routine${prompts.length > 1 ? 's' : ''}'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: prompts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final prompt = prompts[index];
            return _PromptItemCard(
              prompt: prompt,
              formatTime: _formatTime,
              onStart: onStart,
              onAlreadyDone: onAlreadyDone,
              onPartiallyDone: onPartiallyDone,
              onDismiss: onDismiss,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: onClose,
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _PromptItemCard extends StatefulWidget {
  final PendingRoutinePrompt prompt;
  final String Function(String?) formatTime;
  final Future<void> Function(int routineId) onStart;
  final Future<void> Function(int routineId) onAlreadyDone;
  final Future<void> Function(int routineId) onPartiallyDone;
  final Future<void> Function(int routineId) onDismiss;

  const _PromptItemCard({
    required this.prompt,
    required this.formatTime,
    required this.onStart,
    required this.onAlreadyDone,
    required this.onPartiallyDone,
    required this.onDismiss,
  });

  @override
  State<_PromptItemCard> createState() => _PromptItemCardState();
}

class _PromptItemCardState extends State<_PromptItemCard> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.prompt.routineName,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${widget.prompt.stepCount} steps',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (widget.prompt.scheduledTime != null) ...[
                  Text(' · ', style: theme.textTheme.bodySmall),
                  Icon(Icons.access_time, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(
                    widget.formatTime(widget.prompt.scheduledTime),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _isProcessing ? null : () => widget.onStart(widget.prompt.routineId),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Start'),
                ),
                _DoneDropdownButton(
                  isProcessing: _isProcessing,
                  onAlreadyDone: () async {
                    setState(() => _isProcessing = true);
                    await widget.onAlreadyDone(widget.prompt.routineId);
                    if (mounted) setState(() => _isProcessing = false);
                  },
                  onPartiallyDone: () => widget.onPartiallyDone(widget.prompt.routineId),
                ),
                OutlinedButton(
                  onPressed: _isProcessing ? null : () => widget.onDismiss(widget.prompt.routineId),
                  child: const Text('Later'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneDropdownButton extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onAlreadyDone;
  final VoidCallback onPartiallyDone;

  const _DoneDropdownButton({
    required this.isProcessing,
    required this.onAlreadyDone,
    required this.onPartiallyDone,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: isProcessing ? null : onAlreadyDone,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Done'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.only(left: 12, right: 8),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            width: 32,
            child: ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () {
                      showMenu(
                        context: context,
                        position: _getButtonPosition(context),
                        items: [
                          PopupMenuItem(
                            onTap: onPartiallyDone,
                            child: const Text('Partially Done'),
                          ),
                        ],
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.arrow_drop_down, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  RelativeRect _getButtonPosition(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset(0, button.size.height), ancestor: overlay);
    return RelativeRect.fromLTRB(offset.dx, offset.dy, offset.dx + button.size.width, offset.dy);
  }
}

// ==================== Partial Complete Dialog ====================

class _PartialCompleteDialog extends StatefulWidget {
  final String routineName;
  final List<RoutineStep> steps;
  final Set<int> initialCheckedIds;
  final Future<void> Function(Set<int> completedIds) onSubmit;
  final VoidCallback onCancel;

  const _PartialCompleteDialog({
    required this.routineName,
    required this.steps,
    required this.initialCheckedIds,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<_PartialCompleteDialog> createState() => _PartialCompleteDialogState();
}

class _PartialCompleteDialogState extends State<_PartialCompleteDialog> {
  late Set<int> _checkedIds;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _checkedIds = Set<int>.from(widget.initialCheckedIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.routineName} - Mark Steps'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Uncheck any steps you didn\'t complete:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.steps.length,
                itemBuilder: (context, index) {
                  final step = widget.steps[index];
                  return CheckboxListTile(
                    value: _checkedIds.contains(step.id),
                    onChanged: _isProcessing
                        ? null
                        : (value) {
                            setState(() {
                              if (value == true) {
                                _checkedIds.add(step.id);
                              } else {
                                _checkedIds.remove(step.id);
                              }
                            });
                          },
                    title: Text(step.text),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : widget.onCancel,
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isProcessing
              ? null
              : () async {
                  setState(() => _isProcessing = true);
                  await widget.onSubmit(_checkedIds);
                  if (mounted) setState(() => _isProcessing = false);
                },
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Mark Done'),
        ),
      ],
    );
  }
}
