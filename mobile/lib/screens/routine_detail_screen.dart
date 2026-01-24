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

        if (provider.showAnalytics) {
          if (provider.getAnalytics(widget.routineId) == null) {
            _loadAnalytics();
          }
          return _buildAnalyticsView(provider);
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
                Colors.green,
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
            _buildLegendItem(Colors.green, 'Completed'),
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
                      dotColor = Colors.green;
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
                              ? Border.all(color: Colors.green, width: 2)
                              : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '$dayNumber',
                              style: TextStyle(
                                color: isToday ? Colors.green : null,
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
                            const AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${step.completedCount} completed',
                          style:
                              TextStyle(fontSize: 12, color: Colors.green[700]),
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
