import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Routine'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Routine name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(nameController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty && mounted) {
      final provider = context.read<RoutineProvider>();
      final routine = await provider.createRoutine(result.trim());
      if (routine != null && mounted) {
        provider.setCurrentRoutineId(routine.id);
      }
    }
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine'),
        content: Text('Are you sure you want to delete "${routine.name}"?'),
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

    if (confirm == true && mounted) {
      await context.read<RoutineProvider>().deleteRoutine(routine.id);
    }
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

        if (provider.routines.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.repeat,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No routines yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a routine to track repeatable checklists',
                  style: TextStyle(
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _showCreateDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Routine'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        final sortedRoutines = List<Routine>.from(provider.routines)
          ..sort((a, b) => a.name.compareTo(b.name));

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => provider.loadRoutines(),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: sortedRoutines.length,
                itemBuilder: (context, index) {
                  final routine = sortedRoutines[index];
                  final hasActiveExecution =
                      provider.getActiveExecution(routine.id) != null;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: ListTile(
                      title: Text(routine.name),
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
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteRoutine(routine),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => provider.setCurrentRoutineId(routine.id),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: _showCreateDialog,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
