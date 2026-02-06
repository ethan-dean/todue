import 'package:flutter/material.dart';
import '../models/routine.dart';
import '../providers/theme_provider.dart';
import '../services/haptic_service.dart';

class ScheduleSelector extends StatefulWidget {
  final Map<int, String?> initialSchedules;
  final ValueChanged<List<ScheduleEntry>> onSave;

  const ScheduleSelector({
    Key? key,
    required this.initialSchedules,
    required this.onSave,
  }) : super(key: key);

  @override
  State<ScheduleSelector> createState() => _ScheduleSelectorState();
}

class _ScheduleSelectorState extends State<ScheduleSelector> {
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
      HapticService.action();
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
    HapticService.action();
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

  void _toggleDay(int index) {
    HapticService.toggle();
    setState(() {
      if (_schedules.containsKey(index)) {
        _schedules.remove(index);
      } else {
        _schedules[index] = '08:00:00';
      }
    });
  }

  void _save() {
    HapticService.action();
    final entries = _schedules.entries
        .map((e) => ScheduleEntry(dayOfWeek: e.key, promptTime: e.value))
        .toList();
    widget.onSave(entries);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount = _schedules.length;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SCHEDULE',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(16),
            color: primary.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select days and times for routine prompts',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _toggleAll(true),
                      icon: const Icon(Icons.select_all, size: 18),
                      label: const Text('All'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(color: primary.withValues(alpha: 0.5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _toggleAll(false),
                      icon: const Icon(Icons.deselect, size: 18),
                      label: const Text('None'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: enabledCount > 0 ? primary : Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$enabledCount/7',
                        style: TextStyle(
                          color: enabledCount > 0 ? ThemeProvider.contrastOn(primary) : Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Days list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: 7,
              itemBuilder: (context, index) {
                final isEnabled = _schedules.containsKey(index);
                final promptTime = _schedules[index];

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? primary.withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isEnabled ? primary.withValues(alpha: 0.3) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _toggleDay(index),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Checkbox
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isEnabled ? primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isEnabled ? primary : Colors.grey[400]!,
                                width: 2,
                              ),
                            ),
                            child: isEnabled
                                ? Icon(Icons.check, size: 18, color: ThemeProvider.contrastOn(primary))
                                : null,
                          ),
                          const SizedBox(width: 16),
                          // Day name
                          Expanded(
                            child: Text(
                              _days[index],
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: isEnabled ? FontWeight.w600 : FontWeight.w400,
                                color: isEnabled ? primary : Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          // Time picker button
                          if (isEnabled)
                            Material(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              elevation: 1,
                              child: InkWell(
                                onTap: () => _pickTime(index),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.access_time, size: 18, color: primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatTime(promptTime),
                                        style: TextStyle(
                                          color: primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
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

          // Bottom save button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: ThemeProvider.contrastOn(primary),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Schedule',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
