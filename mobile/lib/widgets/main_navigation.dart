import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/todo_screen.dart';
import '../screens/later_lists_screen.dart';
import '../screens/routines_screen.dart';
import '../screens/routine_execution_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/app_dialogs.dart';
import '../providers/later_list_provider.dart';
import '../providers/todo_provider.dart';
import '../providers/routine_provider.dart';
import '../models/routine.dart';
import '../services/haptic_service.dart';
import 'routine_prompt_dialog.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  bool _promptDialogShown = false;

  Future<void> _showPromptDialog(List<PendingRoutinePrompt> prompts) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) => RoutinePromptDialog(
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
          final provider = context.read<RoutineProvider>();
          if (provider.getRoutineDetail(routineId) == null) {
            await provider.loadRoutineDetail(routineId);
          }
          final detail = provider.getRoutineDetail(routineId);
          if (detail == null) return;
          final steps = List<RoutineStep>.from(detail.steps)
            ..sort((a, b) => a.position.compareTo(b.position));
          final checkedStepIds = Set<int>.from(steps.map((s) => s.id));
          if (!dialogContext.mounted) return;
          bool submitted = false;
          await showModalBottomSheet<void>(
            context: dialogContext,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Theme.of(dialogContext).scaffoldBackgroundColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (sheetContext) => PartialCompleteDialog(
              routineName: detail.name,
              steps: steps,
              initialCheckedIds: checkedStepIds,
              onSubmit: (completedIds) async {
                Navigator.of(sheetContext).pop();
                submitted = true;
                await provider.quickCompleteRoutine(routineId, completedStepIds: completedIds.toList());
              },
              onCancel: () {
                Navigator.of(sheetContext).pop();
              },
            ),
          );
          if (submitted && dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
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

    await AppBottomSheet.show(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: controller,
            autofocus: true,
            hintText: 'Routine name',
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              Navigator.of(sheetContext).pop();
              if (value.trim().isNotEmpty && value.trim() != currentName) {
                HapticService.action();
                context.read<RoutineProvider>().updateRoutineName(routineId, value.trim());
              }
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppCancelButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppActionButton(
                  label: 'Save',
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    final text = controller.text.trim();
                    if (text.isNotEmpty && text != currentName) {
                      HapticService.action();
                      context.read<RoutineProvider>().updateRoutineName(routineId, text);
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

  Future<void> _editLaterListName(int listId, String currentName) async {
    final controller = TextEditingController(text: currentName);

    await AppBottomSheet.show(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: controller,
            autofocus: true,
            hintText: 'List name',
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              Navigator.of(sheetContext).pop();
              if (value.trim().isNotEmpty && value.trim() != currentName) {
                HapticService.action();
                context.read<LaterListProvider>().updateListName(listId, value.trim());
              }
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppCancelButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppActionButton(
                  label: 'Save',
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    final text = controller.text.trim();
                    if (text.isNotEmpty && text != currentName) {
                      HapticService.action();
                      context.read<LaterListProvider>().updateListName(listId, text);
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

  Widget _buildNavItem(String label, int index) {
    final isSelected = _selectedIndex == index;
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              letterSpacing: 1.2,
              color: isSelected ? primary : Colors.grey,
            ),
          ),
        ),
      ),
    );
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

        const titleStyle = TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        );

        Widget titleWidget;
        final displayTitle = title.toUpperCase();
        if (isLaterListDetail) {
          final listId = laterListProvider.currentListId!;
          titleWidget = GestureDetector(
            onTap: () => _editLaterListName(listId, title),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(displayTitle, overflow: TextOverflow.ellipsis, style: titleStyle)),
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
                Flexible(child: Text(displayTitle, overflow: TextOverflow.ellipsis, style: titleStyle)),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 16),
              ],
            ),
          );
        } else {
          titleWidget = Text(displayTitle, style: titleStyle);
        }

        return Scaffold(
          appBar: AppBar(
            centerTitle: !(isLaterListDetail || isRoutineDetail),
            title: titleWidget,
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
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3))),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(child: _buildNavItem('NOW', 0)),
                      Expanded(child: _buildNavItem('LATER', 1)),
                      Expanded(child: _buildNavItem('ROUTINES', 2)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
