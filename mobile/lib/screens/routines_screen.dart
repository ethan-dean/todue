import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../widgets/app_dialogs.dart';
import '../providers/routine_provider.dart';
import '../models/routine.dart';
import 'routine_detail_screen.dart';
import 'routine_execution_screen.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({Key? key}) : super(key: key);

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoutineProvider>().loadRoutines();
      context.read<RoutineProvider>().loadPendingPrompts();
    });
  }

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();

    await AppBottomSheet.show(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: nameController,
            autofocus: true,
            hintText: 'Routine name',
            textInputAction: TextInputAction.done,
            onSubmitted: (value) async {
              Navigator.of(context).pop();
              if (value.trim().isNotEmpty) {
                final provider = this.context.read<RoutineProvider>();
                final routine = await provider.createRoutine(value.trim());
                if (routine != null && mounted) {
                  provider.setCurrentRoutineId(routine.id);
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
                    final text = nameController.text.trim();
                    if (text.isNotEmpty) {
                      final provider = this.context.read<RoutineProvider>();
                      final routine = await provider.createRoutine(text);
                      if (routine != null && mounted) {
                        provider.setCurrentRoutineId(routine.id);
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

  void _navigateToExecution(int routineId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RoutineExecutionScreen(routineId: routineId),
      ),
    );
  }

  Future<void> _startRoutine(int routineId) async {
    if (_isStarting) return;
    setState(() => _isStarting = true);
    try {
      final provider = context.read<RoutineProvider>();
      final completion = await provider.startRoutine(routineId);
      if (completion != null && mounted) {
        _navigateToExecution(routineId);
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _deleteRoutine(Routine routine) async {
    await context.read<RoutineProvider>().deleteRoutine(routine.id);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoutineProvider>(
      builder: (context, provider, _) {
        // If a routine is selected, show the detail view inline
        if (provider.currentRoutineId != null) {
          final selectedRoutine = provider.routines
              .where((r) => r.id == provider.currentRoutineId)
              .firstOrNull;

          if (selectedRoutine != null) {
            return PopScope(
              key: ValueKey('detail_${selectedRoutine.id}'),
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                provider.setCurrentRoutineId(null);
              },
              child: RoutineDetailScreen(routineId: selectedRoutine.id),
            );
          } else {
            // Routine might have been deleted
            WidgetsBinding.instance.addPostFrameCallback((_) {
              provider.setCurrentRoutineId(null);
            });
            return const SizedBox.shrink();
          }
        }

        // Show the list of routines
        if (provider.isLoading && provider.routines.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final sortedRoutines = List<Routine>.from(provider.routines)
          ..sort((a, b) => a.name.compareTo(b.name));

        return CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                await _showCreateDialog();
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
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final routine = sortedRoutines[index];
                    final hasActiveExecution =
                        provider.getActiveExecution(routine.id) != null;

                    return Dismissible(
                      key: Key('routine_${routine.id}'),
                      dismissThresholds: const {DismissDirection.endToStart: 0.5},
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        await _deleteRoutine(routine);
                        return false;
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: Text(
                              routine.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                            subtitle: Text(
                              '${routine.stepCount} ${routine.stepCount == 1 ? 'step' : 'steps'}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasActiveExecution)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'In Progress',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  icon: Icon(
                                    hasActiveExecution
                                        ? Icons.play_arrow
                                        : Icons.play_circle_outline,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  onPressed: () {
                                    if (hasActiveExecution) {
                                      _navigateToExecution(routine.id);
                                    } else {
                                      _startRoutine(routine.id);
                                    }
                                  },
                                ),
                              ],
                            ),
                            onTap: () => provider.setCurrentRoutineId(routine.id),
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
                  },
                  childCount: sortedRoutines.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showCreateDialog,
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showCreateDialog,
                child: Container(),
              ),
            ),
          ],
        );
      },
    );
  }
}
