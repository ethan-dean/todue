import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/routine_provider.dart';
import '../models/routine.dart';

class RoutineAnalyticsScreen extends StatefulWidget {
  final int routineId;

  const RoutineAnalyticsScreen({Key? key, required this.routineId})
      : super(key: key);

  @override
  State<RoutineAnalyticsScreen> createState() => _RoutineAnalyticsScreenState();
}

class _RoutineAnalyticsScreenState extends State<RoutineAnalyticsScreen> {
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Consumer<RoutineProvider>(
        builder: (context, provider, _) {
          final analytics = provider.getAnalytics(widget.routineId);

          if (analytics == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats cards
                _buildStatsSection(analytics),
                const SizedBox(height: 24),

                // Calendar section
                _buildCalendarSection(analytics),
                const SizedBox(height: 24),

                // Step breakdown
                if (analytics.stepAnalytics.isNotEmpty)
                  _buildStepBreakdown(analytics),
              ],
            ),
          );
        },
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
                '${(analytics.completionRate * 100).round()}%',
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
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month navigation
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

        // Calendar grid
        _buildCalendarGrid(analytics),

        // Legend
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

    // calendarData is already a Map<String, String> of date -> status
    final statusMap = analytics.calendarData;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // Weekday headers
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

            // Calendar days
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
