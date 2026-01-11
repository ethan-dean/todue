import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';

class DateTimeline extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const DateTimeline({
    Key? key,
    required this.selectedDate,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  State<DateTimeline> createState() => DateTimelineState();
}

class DateTimelineState extends State<DateTimeline> {
  late ScrollController _scrollController;
  final int _daysRange = 365;
  final double _itemWidth = 60.0;
  final double _itemMargin = 4.0;
  DateTime? _hoverDate;
  
  // Auto-scroll state
  Timer? _autoScrollTimer;
  double? _currentDragX;
  double _currentWidgetWidth = 0;

  /// Check if a drag position intersects with a date bubble
  /// Returns the date if hit, null otherwise
  DateTime? checkDragPosition(Offset globalPosition) {
    // Convert global position to local coordinate
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;

    final localPosition = box.globalToLocal(globalPosition);
    
    // Update drag state for auto-scroll
    _currentDragX = localPosition.dx;
    _currentWidgetWidth = box.size.width;
    _updateAutoScroll();

    // Check if within the widget's vertical bounds
    if (localPosition.dy < 0 || localPosition.dy > box.size.height) {
      if (_hoverDate != null) {
        setState(() {
          _hoverDate = null;
        });
      }
      return null;
    }

    // Determine scroll offset to find the item index
    final scrollOffset = _scrollController.offset;
    final itemFullWidth = _itemWidth + (_itemMargin * 2);
    
    // Calculate which item is at the x position
    final index = ((localPosition.dx + scrollOffset) / itemFullWidth).floor();
    
    // Validate index
    if (index < 0 || index >= (_daysRange * 2 + 1)) {
      if (_hoverDate != null) {
        setState(() {
          _hoverDate = null;
        });
      }
      return null;
    }

    // Convert index back to date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayOffset = index - _daysRange;
    final date = today.add(Duration(days: dayOffset));

    if (_hoverDate != date) {
      setState(() {
        _hoverDate = date;
      });
    }
    
    return date;
  }

  void clearHover() {
    _stopAutoScroll();
    if (_hoverDate != null) {
      setState(() {
        _hoverDate = null;
      });
    }
  }

  void _updateAutoScroll() {
    const edgeThreshold = 70.0; // Distance from edge to start scrolling
    
    if (_currentDragX == null) {
      _stopAutoScroll();
      return;
    }

    final inLeftZone = _currentDragX! < edgeThreshold;
    final inRightZone = _currentDragX! > _currentWidgetWidth - edgeThreshold;

    if ((inLeftZone || inRightZone)) {
      if (_autoScrollTimer == null) {
        _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), _onAutoScrollTick);
      }
    } else {
      _stopAutoScroll();
    }
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _currentDragX = null;
  }

  void _onAutoScrollTick(Timer timer) {
    if (_currentDragX == null || !_scrollController.hasClients) {
      _stopAutoScroll();
      return;
    }

    const edgeThreshold = 70.0;
    const maxScrollSpeed = 20.0; // Max pixels per tick (approx 1200px/sec)

    double scrollDelta = 0;

    if (_currentDragX! < edgeThreshold) {
      // Scroll Left
      // Calculate intensity (0.0 to 1.0) based on how close to edge
      // Closer to 0 = faster
      final distance = _currentDragX!.clamp(0.0, edgeThreshold);
      final intensity = 1.0 - (distance / edgeThreshold);
      scrollDelta = -maxScrollSpeed * intensity;
    } else if (_currentDragX! > _currentWidgetWidth - edgeThreshold) {
      // Scroll Right
      final distance = (_currentWidgetWidth - _currentDragX!).clamp(0.0, edgeThreshold);
      final intensity = 1.0 - (distance / edgeThreshold);
      scrollDelta = maxScrollSpeed * intensity;
    }

    if (scrollDelta != 0) {
      final newOffset = _scrollController.offset + scrollDelta;
      // Clamp to bounds? ListView usually handles overscroll, but let's be safe
      // Just jump/animate
      _scrollController.jumpTo(newOffset);
    }
  }

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
    _stopAutoScroll();
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
                  final isHovering = _hoverDate != null && _isSameDay(date, _hoverDate!);
        
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
              ),
            );
          }
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
