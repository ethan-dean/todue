import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';

class DateTimeline extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final Function(DateTime, Todo)? onTodoDropped;

  const DateTimeline({
    Key? key,
    required this.selectedDate,
    required this.onDateSelected,
    this.onTodoDropped,
  }) : super(key: key);

  @override
  State<DateTimeline> createState() => _DateTimelineState();
}

class _DateTimelineState extends State<DateTimeline> {
  late ScrollController _scrollController;
  final int _daysRange = 365;
  final double _itemWidth = 60.0;
  final double _itemMargin = 4.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Scroll to selected date after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDate(widget.selectedDate, animate: false);
    });
  }

  @override
  void didUpdateWidget(DateTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _scrollToDate(widget.selectedDate, animate: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToDate(DateTime date, {bool animate = true}) {
    // Calculate index relative to today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = date.difference(today).inDays;
    final index = _daysRange + diff;

    // Calculate total width of one item including margin
    final fullItemWidth = _itemWidth + (_itemMargin * 2);

    // Center the item
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = (index * fullItemWidth) - (screenWidth / 2) + (fullItemWidth / 2);

    if (_scrollController.hasClients) {
      if (animate) {
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _scrollController.jumpTo(offset);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      height: 85,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _daysRange * 2 + 1, // Past and future
        itemBuilder: (context, index) {
          final dayOffset = index - _daysRange;
          final date = today.add(Duration(days: dayOffset));
          final isSelected = _isSameDay(date, widget.selectedDate);
          final isToday = _isSameDay(date, today);

          return DragTarget<Todo>(
            onWillAccept: (todo) => todo != null && !_isSameDay(date, widget.selectedDate),
            onAccept: (todo) {
              if (widget.onTodoDropped != null) {
                widget.onTodoDropped!(date, todo);
              }
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              
              return GestureDetector(
                onTap: () => widget.onDateSelected(date),
                child: Container(
                  width: _itemWidth,
                  margin: EdgeInsets.symmetric(vertical: 10, horizontal: _itemMargin),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.green
                        : (isToday ? Colors.green.withOpacity(0.1) : (isHovering ? Colors.green.withOpacity(0.2) : Colors.transparent)),
                    borderRadius: BorderRadius.circular(16),
                    border: (isToday && !isSelected) || isHovering
                        ? Border.all(color: Colors.green, width: isHovering ? 2 : 1)
                        : null,
                    boxShadow: isHovering ? [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, spreadRadius: 2)] : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('E').format(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('M/d').format(date),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
