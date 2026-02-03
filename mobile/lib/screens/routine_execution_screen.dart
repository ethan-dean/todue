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
  int? _editingStepId;
  int? _selectedStepIndex;
  final TextEditingController _notesController = TextEditingController();

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
    _notesController.dispose();
    super.dispose();
  }

  void _startEditingNotes(RoutineStep step) {
    setState(() {
      _editingStepId = step.id;
      _notesController.text = step.notes ?? '';
    });
  }

  Future<void> _saveNotes(int stepId) async {
    final notes = _notesController.text.trim();
    await context.read<RoutineProvider>().updateStepNotes(
          widget.routineId,
          stepId,
          notes.isEmpty ? null : notes,
        );
    setState(() {
      _editingStepId = null;
    });
  }

  void _cancelEditingNotes() {
    setState(() {
      _editingStepId = null;
    });
  }

  Future<void> _completeStep(int completionId, int stepId) async {
    await context.read<RoutineProvider>().completeStep(
          completionId,
          stepId,
          'complete',
        );
    // Reset selection to auto-select first pending step
    setState(() {
      _selectedStepIndex = null;
    });
  }

  Future<void> _skipStep(int completionId, int stepId) async {
    await context.read<RoutineProvider>().completeStep(
          completionId,
          stepId,
          'skip',
        );
    // Reset selection to auto-select first pending step
    setState(() {
      _selectedStepIndex = null;
    });
  }

  void _selectStep(int index) {
    if (_editingStepId != null) return;
    setState(() {
      _selectedStepIndex = index;
    });
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

        // Find first pending step (for auto-selection)
        int firstPendingStepIndex = -1;
        for (int i = 0; i < sortedSteps.length; i++) {
          final sc = completionMap[sortedSteps[i].id];
          if (sc == null || sc.status == RoutineStepCompletionStatus.pending) {
            firstPendingStepIndex = i;
            break;
          }
        }

        // Use selected step if set, otherwise default to first pending
        final currentStepIndex = _selectedStepIndex ?? firstPendingStepIndex;
        final allDone = firstPendingStepIndex == -1;

        return Scaffold(
          appBar: AppBar(
            title: Text(detail.name),
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
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
                            AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
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
                    final isEditing = _editingStepId == step.id;

                    return GestureDetector(
                      onTap: () => _selectStep(index),
                      child: Card(
                        elevation: isCurrent ? 4 : 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isCurrent
                              ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
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
                                        ? Theme.of(context).colorScheme.primary
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

                            // Notes section - show for current step
                            if (isCurrent) ...[
                              const SizedBox(height: 12),
                              if (isEditing) ...[
                                // Editing mode
                                TextField(
                                  controller: _notesController,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    hintText: 'Add notes for this step...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  maxLines: 3,
                                  minLines: 1,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: _cancelEditingNotes,
                                      child: const Text('Cancel'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _saveNotes(step.id),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Save'),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                // Display mode
                                InkWell(
                                  onTap: () => _startEditingNotes(step),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: step.notes != null &&
                                                  step.notes!.isNotEmpty
                                              ? Text(
                                                  step.notes!,
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                  ),
                                                )
                                              : Text(
                                                  'Add notes...',
                                                  style: TextStyle(
                                                    color: Colors.grey[500],
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                        ),
                                        Icon(
                                          Icons.edit,
                                          size: 18,
                                          color: Colors.grey[500],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: isEditing
                                          ? null
                                          : () => _completeStep(
                                              execution.id, step.id),
                                      icon: const Icon(Icons.check),
                                      label: const Text('Complete'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: isEditing
                                          ? null
                                          : () =>
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

                            // Show notes for completed/skipped steps
                            if ((isCompleted || isSkipped) &&
                                step.notes != null &&
                                step.notes!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                step.notes!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )); // Close GestureDetector
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
                          backgroundColor: Theme.of(context).colorScheme.primary,
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
