import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/app_dialogs.dart';
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
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoutineProvider>().loadRoutineDetail(widget.routineId);
    });
  }

  void _loadAnalytics() {
    final startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    context.read<RoutineProvider>().loadAnalytics(
          widget.routineId,
          _formatDate(startDate),
          _formatDate(endDate),
        );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadAnalytics();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
    _loadAnalytics();
  }

  Future<void> _addStep() async {
    final textController = TextEditingController();
    final notesController = TextEditingController();

    await AppBottomSheet.show(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: textController,
            autofocus: true,
            hintText: 'Step text',
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: notesController,
            hintText: 'Notes (optional)',
            maxLines: 3,
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
                  label: 'Add',
                  onPressed: () {
                    Navigator.of(context).pop();
                    var text = textController.text.trim();
                    final notes = notesController.text.trim();
                    if (text.isEmpty && notes.isNotEmpty) {
                      text = 'Step text';
                    }
                    if (text.isNotEmpty) {
                      this.context.read<RoutineProvider>().createStep(
                            widget.routineId,
                            text,
                            notes: notes.isEmpty ? null : notes,
                          );
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

  Future<void> _editStep(RoutineStep step) async {
    final textController = TextEditingController(text: step.text);
    final notesController = TextEditingController(text: step.notes ?? '');

    await AppBottomSheet.show(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: textController,
            autofocus: true,
            hintText: 'Step text',
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: notesController,
            hintText: 'Notes (optional)',
            maxLines: 3,
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
                  label: 'Save',
                  onPressed: () {
                    Navigator.of(context).pop();
                    var newText = textController.text.trim();
                    if (newText.isEmpty) {
                      newText = 'Step text';
                    }
                    final provider = this.context.read<RoutineProvider>();
                    final newNotes = notesController.text.trim();

                    if (newText != step.text) {
                      provider.updateStepText(widget.routineId, step.id, newText);
                    }

                    final oldNotes = step.notes ?? '';
                    if (newNotes != oldNotes) {
                      provider.updateStepNotes(
                        widget.routineId,
                        step.id,
                        newNotes.isEmpty ? null : newNotes,
                      );
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

  Future<void> _deleteStep(RoutineStep step) async {
    await context
        .read<RoutineProvider>()
        .deleteStep(widget.routineId, step.id);
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

        if (provider.showAnalytics) {
          if (provider.getAnalytics(widget.routineId) == null) {
            _loadAnalytics();
          }
          return _buildAnalyticsView(provider);
        }

        final sortedSteps = List<RoutineStep>.from(detail.steps)
          ..sort((a, b) => a.position.compareTo(b.position));

        return Column(
          children: [
            // Schedule section
            Card(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: ListTile(
                leading: Icon(Icons.schedule, color: Theme.of(context).colorScheme.primary),
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
                    'Steps',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: _addStep,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
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
                        icon: Icon(
                          hasActiveExecution ? Icons.play_arrow : Icons.play_circle_outline,
                          size: 18,
                        ),
                        label: Text(hasActiveExecution ? 'Continue' : 'Start'),
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: sortedSteps.isEmpty
                              ? Colors.grey
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
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
                  : CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          sliver: SliverReorderableList(
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) newIndex--;
                            final step = sortedSteps[oldIndex];
                            provider.updateStepPosition(
                              widget.routineId,
                              step.id,
                              newIndex,
                            );
                          },
                          itemCount: sortedSteps.length,
                          itemBuilder: (context, index) {
                            final step = sortedSteps[index];
                            final item = Dismissible(
                              key: ValueKey('dismiss_${step.id}'),
                              dismissThresholds: const {DismissDirection.endToStart: 0.5},
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) async {
                                await _deleteStep(step);
                                return false;
                              },
                              child: Material(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(color: Theme.of(context).colorScheme.primary),
                                        ),
                                      ),
                                      title: Text(step.text),
                                      subtitle: step.notes != null ? Text(step.notes!) : null,
                                      onTap: () => _editStep(step),
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
                              ),
                            );
                            return ReorderableDelayedDragStartListener(
                              key: ValueKey(step.id),
                              index: index,
                              child: item,
                            );
                          },
                        ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  // ==================== Analytics View ====================

  Widget _buildAnalyticsView(RoutineProvider provider) {
    final analytics = provider.getAnalytics(widget.routineId);

    if (analytics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsSection(analytics),
          const SizedBox(height: 24),
          _buildCalendarSection(analytics),
          const SizedBox(height: 24),
          if (analytics.stepAnalytics.isNotEmpty)
            _buildStepBreakdown(analytics),
        ],
      ),
    );
  }

  Widget _buildStatsSection(RoutineAnalytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistics',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Current Streak',
                '${analytics.currentStreak}',
                Icons.local_fire_department,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Longest Streak',
                '${analytics.longestStreak}',
                Icons.emoji_events,
                Colors.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Completion Rate',
                '${analytics.completionRate.round()}%',
                Icons.pie_chart,
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Completions',
                '${analytics.totalCompletions}',
                Icons.check_circle,
                Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection(RoutineAnalytics analytics) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: _previousMonth,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            IconButton(
              onPressed: _nextMonth,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCalendarGrid(analytics),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(Theme.of(context).colorScheme.primary, 'Completed'),
            const SizedBox(width: 16),
            _buildLegendItem(Colors.red, 'Abandoned'),
            const SizedBox(width: 16),
            _buildLegendItem(Colors.grey[300]!, 'No data'),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(RoutineAnalytics analytics) {
    final firstDayOfMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday
    final daysInMonth = lastDayOfMonth.day;

    final statusMap = analytics.calendarData;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            ...List.generate(6, (weekIndex) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: List.generate(7, (dayIndex) {
                    final dayNumber =
                        weekIndex * 7 + dayIndex - firstWeekday + 1;
                    if (dayNumber < 1 || dayNumber > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 36));
                    }

                    final date = DateTime(
                        _selectedMonth.year, _selectedMonth.month, dayNumber);
                    final dateStr = _formatDate(date);
                    final status = statusMap[dateStr];

                    Color? dotColor;
                    if (status == 'COMPLETED') {
                      dotColor = Theme.of(context).colorScheme.primary;
                    } else if (status == 'ABANDONED') {
                      dotColor = Colors.red;
                    }

                    final isToday = _isToday(date);

                    return Expanded(
                      child: Container(
                        height: 36,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: isToday
                              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                              : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '$dayNumber',
                              style: TextStyle(
                                color: isToday ? Theme.of(context).colorScheme.primary : null,
                                fontWeight: isToday ? FontWeight.bold : null,
                              ),
                            ),
                            if (dotColor != null)
                              Positioned(
                                bottom: 2,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildStepBreakdown(RoutineAnalytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step Performance',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: analytics.stepAnalytics.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final step = analytics.stepAnalytics[index];
              final total = step.completedCount + step.skippedCount;
              final completionRate =
                  total > 0 ? step.completedCount / total : 0.0;

              return ListTile(
                title: Text(step.stepText),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: completionRate,
                        minHeight: 8,
                        backgroundColor: Colors.orange.withOpacity(0.3),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${step.completedCount} completed',
                          style:
                              TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                        ),
                        const Text(' • '),
                        Text(
                          '${step.skippedCount} skipped',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange[700]),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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

  Future<void> _pickTime(int dayIndex) async {
    final currentTime = _schedules[dayIndex] ?? '08:00:00';
    final parts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        _schedules[dayIndex] = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
      });
    }
  }

  String _formatTime(String? time) {
    if (time == null) return '8:00 AM';
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  void _toggleAll(bool enable) {
    setState(() {
      if (enable) {
        for (int i = 0; i < 7; i++) {
          if (!_schedules.containsKey(i)) {
            _schedules[i] = '08:00:00';
          }
        }
      } else {
        _schedules.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount = _schedules.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Schedule',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select days and times for routine prompts',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            // Quick actions
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _toggleAll(true),
                  icon: const Icon(Icons.select_all, size: 18),
                  label: const Text('All'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _toggleAll(false),
                  icon: const Icon(Icons.deselect, size: 18),
                  label: const Text('None'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: enabledCount > 0 ? Theme.of(context).colorScheme.primaryContainer : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$enabledCount/7 days',
                    style: TextStyle(
                      color: enabledCount > 0 ? Theme.of(context).colorScheme.primary : Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Days list
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 350),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: 7,
                itemBuilder: (context, index) {
                  final isEnabled = _schedules.containsKey(index);
                  final promptTime = _schedules[index];

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isEnabled ? Theme.of(context).colorScheme.primaryContainer : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isEnabled ? Theme.of(context).colorScheme.primary.withOpacity(0.3) : Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (isEnabled) {
                            _schedules.remove(index);
                          } else {
                            _schedules[index] = '08:00:00';
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            // Checkbox
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isEnabled ? Theme.of(context).colorScheme.primary : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isEnabled ? Theme.of(context).colorScheme.primary : Colors.grey[400]!,
                                  width: 2,
                                ),
                              ),
                              child: isEnabled
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            // Day name
                            Expanded(
                              child: Text(
                                _days[index],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isEnabled ? FontWeight.w600 : FontWeight.normal,
                                  color: isEnabled ? Theme.of(context).colorScheme.primary : Colors.grey[700],
                                ),
                              ),
                            ),
                            // Time picker button
                            if (isEnabled)
                              Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: () => _pickTime(index),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.access_time, size: 16, color: Theme.of(context).colorScheme.primary),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatTime(promptTime),
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_schedules),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Save'),
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
