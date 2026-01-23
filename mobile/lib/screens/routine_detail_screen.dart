import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/routine_provider.dart';
import '../models/routine.dart';
import 'routine_execution_screen.dart';

class RoutineDetailScreen extends StatefulWidget {
  final int routineId;

  const RoutineDetailScreen({Key? key, required this.routineId})
      : super(key: key);

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoutineProvider>().loadRoutineDetail(widget.routineId);
    });
  }

  Future<void> _addStep() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Step'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Step text',
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
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty && mounted) {
      await context
          .read<RoutineProvider>()
          .createStep(widget.routineId, result.trim());
    }
  }

  Future<void> _editStep(RoutineStep step) async {
    final controller = TextEditingController(text: step.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Step'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Step text',
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
          .updateStepText(widget.routineId, step.id, result.trim());
    }
  }

  Future<void> _deleteStep(RoutineStep step) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Step'),
        content: Text('Delete "${step.text}"?'),
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
      await context
          .read<RoutineProvider>()
          .deleteStep(widget.routineId, step.id);
    }
  }

  Future<void> _editSchedule(RoutineDetail detail) async {
    final selectedDays = <int, String?>{};
    for (var schedule in detail.schedules) {
      selectedDays[schedule.dayOfWeek] = schedule.promptTime ?? '08:00:00';
    }

    final result = await showDialog<Map<int, String?>>(
      context: context,
      builder: (context) => _ScheduleDialog(initialSchedules: selectedDays),
    );

    if (result != null && mounted) {
      final schedules = result.entries
          .map((e) => ScheduleEntry(dayOfWeek: e.key, promptTime: e.value))
          .toList();
      await context.read<RoutineProvider>().setSchedules(widget.routineId, schedules);
    }
  }

  Future<void> _startRoutine() async {
    final provider = context.read<RoutineProvider>();
    final completion = await provider.startRoutine(widget.routineId);
    if (completion != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              RoutineExecutionScreen(routineId: widget.routineId),
        ),
      );
    }
  }

  String _getScheduleSummary(List<RoutineSchedule> schedules) {
    if (schedules.isEmpty) return 'No schedule set';

    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final scheduledDays = schedules
        .where((s) => s.promptTime != null)
        .map((s) => days[s.dayOfWeek])
        .toList();

    if (scheduledDays.isEmpty) return 'No prompts scheduled';
    if (scheduledDays.length == 7) return 'Every day';
    return scheduledDays.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoutineProvider>(
      builder: (context, provider, _) {
        final detail = provider.getRoutineDetail(widget.routineId);
        final hasActiveExecution =
            provider.getActiveExecution(widget.routineId) != null;

        if (detail == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final sortedSteps = List<RoutineStep>.from(detail.steps)
          ..sort((a, b) => a.position.compareTo(b.position));

        return Stack(
          children: [
            Column(
              children: [
                // Schedule section
                Card(
                  margin: const EdgeInsets.all(16),
                  child: ListTile(
                    leading: const Icon(Icons.schedule, color: Colors.green),
                    title: const Text('Schedule'),
                    subtitle: Text(_getScheduleSummary(detail.schedules)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _editSchedule(detail),
                  ),
                ),

                // Steps header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Steps (${sortedSteps.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton.icon(
                        onPressed: _addStep,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                ),

                // Steps list
                Expanded(
                  child: sortedSteps.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.list, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'No steps yet',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: sortedSteps.length,
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) newIndex--;
                            final step = sortedSteps[oldIndex];
                            provider.updateStepPosition(
                              widget.routineId,
                              step.id,
                              newIndex,
                            );
                          },
                          itemBuilder: (context, index) {
                            final step = sortedSteps[index];
                            return Card(
                              key: ValueKey(step.id),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green[100],
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(color: Colors.green[800]),
                                  ),
                                ),
                                title: Text(step.text),
                                subtitle:
                                    step.notes != null ? Text(step.notes!) : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _editStep(step),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _deleteStep(step),
                                    ),
                                    const Icon(Icons.drag_handle),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: sortedSteps.isEmpty
                    ? null
                    : hasActiveExecution
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => RoutineExecutionScreen(
                                    routineId: widget.routineId),
                              ),
                            );
                          }
                        : _startRoutine,
                backgroundColor:
                    sortedSteps.isEmpty ? Colors.grey : Colors.green,
                icon: Icon(
                  hasActiveExecution ? Icons.play_arrow : Icons.play_circle_outline,
                  color: Colors.white,
                ),
                label: Text(
                  hasActiveExecution ? 'Continue' : 'Start',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScheduleDialog extends StatefulWidget {
  final Map<int, String?> initialSchedules;

  const _ScheduleDialog({required this.initialSchedules});

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late Map<int, String?> _schedules;
  final _days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  void initState() {
    super.initState();
    _schedules = Map.from(widget.initialSchedules);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Schedule'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: 7,
          itemBuilder: (context, index) {
            final isEnabled = _schedules.containsKey(index);
            return CheckboxListTile(
              title: Text(_days[index]),
              value: isEnabled,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _schedules[index] = '08:00:00';
                  } else {
                    _schedules.remove(index);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_schedules),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
