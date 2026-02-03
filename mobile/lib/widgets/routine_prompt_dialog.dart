import 'package:flutter/material.dart';
import '../models/routine.dart';

class RoutinePromptDialog extends StatelessWidget {
  final List<PendingRoutinePrompt> prompts;
  final Future<void> Function(int routineId) onStart;
  final Future<void> Function(int routineId) onAlreadyDone;
  final Future<void> Function(int routineId) onPartiallyDone;
  final Future<void> Function(int routineId) onDismiss;
  final VoidCallback onClose;

  const RoutinePromptDialog({
    Key? key,
    required this.prompts,
    required this.onStart,
    required this.onAlreadyDone,
    required this.onPartiallyDone,
    required this.onDismiss,
    required this.onClose,
  }) : super(key: key);

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
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Time for Your Routine${prompts.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 20),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: prompts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final prompt = prompts[index];
                  return PromptItemCard(
                    prompt: prompt,
                    formatTime: _formatTime,
                    onStart: onStart,
                    onAlreadyDone: onAlreadyDone,
                    onPartiallyDone: onPartiallyDone,
                    onDismiss: onDismiss,
                  );
                },
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: onClose,
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PromptItemCard extends StatefulWidget {
  final PendingRoutinePrompt prompt;
  final String Function(String?) formatTime;
  final Future<void> Function(int routineId) onStart;
  final Future<void> Function(int routineId) onAlreadyDone;
  final Future<void> Function(int routineId) onPartiallyDone;
  final Future<void> Function(int routineId) onDismiss;

  const PromptItemCard({
    Key? key,
    required this.prompt,
    required this.formatTime,
    required this.onStart,
    required this.onAlreadyDone,
    required this.onPartiallyDone,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<PromptItemCard> createState() => _PromptItemCardState();
}

class _PromptItemCardState extends State<PromptItemCard> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

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
                SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: _isProcessing ? null : () => widget.onStart(widget.prompt.routineId),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start'),
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: primary,
                    ),
                  ),
                ),
                DoneDropdownButton(
                  isProcessing: _isProcessing,
                  onAlreadyDone: () async {
                    setState(() => _isProcessing = true);
                    await widget.onAlreadyDone(widget.prompt.routineId);
                    if (mounted) setState(() => _isProcessing = false);
                  },
                  onPartiallyDone: () => widget.onPartiallyDone(widget.prompt.routineId),
                ),
                SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : () => widget.onDismiss(widget.prompt.routineId),
                    child: const Text('Later'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DoneDropdownButton extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onAlreadyDone;
  final VoidCallback onPartiallyDone;

  const DoneDropdownButton({
    Key? key,
    required this.isProcessing,
    required this.onAlreadyDone,
    required this.onPartiallyDone,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

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
                backgroundColor: primary,
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
                      _showStyledDropdown(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
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

  void _showStyledDropdown(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: buttonPosition.dx,
              top: buttonPosition.dy + button.size.height + 4,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    onPartiallyDone();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      'Partially Done',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class PartialCompleteDialog extends StatefulWidget {
  final String routineName;
  final List<RoutineStep> steps;
  final Set<int> initialCheckedIds;
  final Future<void> Function(Set<int> completedIds) onSubmit;
  final VoidCallback onCancel;

  const PartialCompleteDialog({
    Key? key,
    required this.routineName,
    required this.steps,
    required this.initialCheckedIds,
    required this.onSubmit,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<PartialCompleteDialog> createState() => _PartialCompleteDialogState();
}

class _PartialCompleteDialogState extends State<PartialCompleteDialog> {
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
