import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/routine.dart';
import '../providers/routine_provider.dart';
import '../providers/theme_provider.dart';
import '../services/haptic_service.dart';

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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onClose,
        ),
        title: Text(
          'SCHEDULED ROUTINE${prompts.length > 1 ? 'S' : ''}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
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
    final routineProvider = context.watch<RoutineProvider>();
    final hasActiveExecution =
        routineProvider.getActiveExecution(widget.prompt.routineId) != null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: _isProcessing ? null : () {
                      HapticService.action();
                      widget.onStart(widget.prompt.routineId);
                    },
                    icon: Icon(
                      hasActiveExecution ? Icons.play_arrow : Icons.play_circle_outline,
                      size: 18,
                    ),
                    label: Text(hasActiveExecution ? 'Continue' : 'Start'),
                    style: FilledButton.styleFrom(
                      foregroundColor: ThemeProvider.contrastOn(primary),
                      backgroundColor: primary,
                    ),
                  ),
                ),
                DoneDropdownButton(
                  isProcessing: _isProcessing,
                  onAlreadyDone: () async {
                    HapticService.action();
                    setState(() => _isProcessing = true);
                    await widget.onAlreadyDone(widget.prompt.routineId);
                    if (mounted) setState(() => _isProcessing = false);
                  },
                  onPartiallyDone: () {
                    HapticService.action();
                    widget.onPartiallyDone(widget.prompt.routineId);
                  },
                ),
                SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : () {
                      HapticService.action();
                      widget.onDismiss(widget.prompt.routineId);
                    },
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

class DoneDropdownButton extends StatefulWidget {
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
  State<DoneDropdownButton> createState() => _DoneDropdownButtonState();
}

class _DoneDropdownButtonState extends State<DoneDropdownButton> {
  final GlobalKey _buttonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      key: _buttonKey,
      height: 40,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: widget.isProcessing ? null : widget.onAlreadyDone,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Done'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: ThemeProvider.contrastOn(primary),
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
              onPressed: widget.isProcessing
                  ? null
                  : () {
                      _showStyledDropdown();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: ThemeProvider.contrastOn(primary),
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

  void _showStyledDropdown() {
    final RenderBox renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final Offset position = renderBox.localToGlobal(Offset.zero);
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
              left: position.dx,
              top: position.dy - 6,
              child: Material(
                elevation: 2,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                color: theme.colorScheme.surface,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    widget.onPartiallyDone();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.checklist, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Partially Done',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${widget.routineName} - Mark Steps',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
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
                final isChecked = _checkedIds.contains(step.id);
                final primary = Theme.of(context).colorScheme.primary;
                return GestureDetector(
                  onTap: _isProcessing
                      ? null
                      : () {
                          HapticService.toggle();
                          setState(() {
                            if (isChecked) {
                              _checkedIds.remove(step.id);
                            } else {
                              _checkedIds.add(step.id);
                            }
                          });
                        },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isChecked ? primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isChecked ? primary : Theme.of(context).colorScheme.outline,
                              width: 2,
                            ),
                          ),
                          child: isChecked
                              ? Icon(Icons.check, size: 18, color: ThemeProvider.contrastOn(primary))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            step.text,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: isChecked
                                      ? Theme.of(context).textTheme.bodyLarge?.color
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isProcessing
                  ? null
                  : () async {
                      setState(() => _isProcessing = true);
                      await widget.onSubmit(_checkedIds);
                      if (mounted) setState(() => _isProcessing = false);
                    },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Mark Done'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: ThemeProvider.contrastOn(Theme.of(context).colorScheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : widget.onCancel,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF3A3A3C) : Colors.grey[200],
                foregroundColor: isDark ? Colors.white : Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
