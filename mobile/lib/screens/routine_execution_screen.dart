import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/routine_provider.dart';
import '../models/routine.dart';

class RoutineExecutionScreen extends StatefulWidget {
  final int routineId;

  const RoutineExecutionScreen({Key? key, required this.routineId})
      : super(key: key);

  @override
  State<RoutineExecutionScreen> createState() => _RoutineExecutionScreenState();
}

class _RoutineExecutionScreenState extends State<RoutineExecutionScreen> {
  final Map<int, TextEditingController> _notesControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<RoutineProvider>();
      provider.loadRoutineDetail(widget.routineId);
      provider.loadActiveExecution(widget.routineId);
    });
  }

  @override
  void dispose() {
    for (final controller in _notesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getNotesController(RoutineStepCompletion sc) {
    if (!_notesControllers.containsKey(sc.stepId)) {
      _notesControllers[sc.stepId] = TextEditingController(text: sc.notes ?? '');
    }
    return _notesControllers[sc.stepId]!;
  }

  Future<void> _completeStep(int completionId, int stepId) async {
    final notes = _notesControllers[stepId]?.text;
    await context.read<RoutineProvider>().completeStep(
          completionId,
          stepId,
          'complete',
          notes: notes?.isNotEmpty == true ? notes : null,
        );
  }

  Future<void> _skipStep(int completionId, int stepId) async {
    final notes = _notesControllers[stepId]?.text;
    await context.read<RoutineProvider>().completeStep(
          completionId,
          stepId,
          'skip',
          notes: notes?.isNotEmpty == true ? notes : null,
        );
  }

  Future<void> _finishExecution(int completionId) async {
    final success =
        await context.read<RoutineProvider>().finishExecution(completionId);
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _abandonExecution(int completionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon Routine'),
        content: const Text(
            'Are you sure you want to abandon this routine? Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success =
          await context.read<RoutineProvider>().abandonExecution(completionId);
      if (success && mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoutineProvider>(
      builder: (context, provider, _) {
        final detail = provider.getRoutineDetail(widget.routineId);
        final execution = provider.getActiveExecution(widget.routineId);

        if (detail == null || execution == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Loading...'),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // Sort steps by position
        final sortedSteps = List<RoutineStep>.from(detail.steps)
          ..sort((a, b) => a.position.compareTo(b.position));

        // Map step completions by stepId
        final completionMap = <int, RoutineStepCompletion>{};
        for (final sc in execution.stepCompletions) {
          completionMap[sc.stepId] = sc;
        }

        // Calculate progress
        final totalSteps = sortedSteps.length;
        final completedSteps = execution.stepCompletions
            .where((sc) =>
                sc.status == RoutineStepCompletionStatus.completed ||
                sc.status == RoutineStepCompletionStatus.skipped)
            .length;
        final progress = totalSteps > 0 ? completedSteps / totalSteps : 0.0;

        // Find current step (first pending)
        int currentStepIndex = -1;
        for (int i = 0; i < sortedSteps.length; i++) {
          final sc = completionMap[sortedSteps[i].id];
          if (sc == null || sc.status == RoutineStepCompletionStatus.pending) {
            currentStepIndex = i;
            break;
          }
        }

        final allDone = currentStepIndex == -1;

        return Scaffold(
          appBar: AppBar(
            title: Text(detail.name),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'abandon') {
                    _abandonExecution(execution.id);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'abandon',
                    child: Row(
                      children: [
                        Icon(Icons.close, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Abandon', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Progress section
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.green.withOpacity(0.1),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '$completedSteps of $totalSteps',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        backgroundColor: Colors.grey[300],
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                  ],
                ),
              ),

              // Steps list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedSteps.length,
                  itemBuilder: (context, index) {
                    final step = sortedSteps[index];
                    final sc = completionMap[step.id];
                    final status =
                        sc?.status ?? RoutineStepCompletionStatus.pending;
                    final isCurrent = index == currentStepIndex;
                    final isCompleted =
                        status == RoutineStepCompletionStatus.completed;
                    final isSkipped =
                        status == RoutineStepCompletionStatus.skipped;

                    return Card(
                      elevation: isCurrent ? 4 : 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isCurrent
                            ? const BorderSide(color: Colors.green, width: 2)
                            : BorderSide.none,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Step header
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isCompleted
                                      ? Colors.green
                                      : isSkipped
                                          ? Colors.orange
                                          : Colors.grey[300],
                                  child: isCompleted
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 18)
                                      : isSkipped
                                          ? const Icon(Icons.skip_next,
                                              color: Colors.white, size: 18)
                                          : Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    step.text,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      decoration: isCompleted || isSkipped
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: isCompleted || isSkipped
                                          ? Colors.grey
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Show notes field for current step
                            if (isCurrent && sc != null) ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: _getNotesController(sc),
                                decoration: const InputDecoration(
                                  hintText: 'Add notes (optional)',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _completeStep(execution.id, step.id),
                                      icon: const Icon(Icons.check),
                                      label: const Text('Complete'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _skipStep(execution.id, step.id),
                                      icon: const Icon(Icons.skip_next),
                                      label: const Text('Skip'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.orange,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // Show completed notes if any
                            if ((isCompleted || isSkipped) &&
                                sc?.notes != null &&
                                sc!.notes!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                sc.notes!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Finish button
              if (allDone)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _finishExecution(execution.id),
                        icon: const Icon(Icons.celebration),
                        label: const Text('Finish Routine'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
