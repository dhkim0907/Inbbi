import 'package:flutter/material.dart';

import '../../features/calendar/calendar_event.dart';
import '../theme/app_colors.dart';

/// 여러 날짜에 걸친 일정을 주 경계에서 나누어 표시한다.
class CalendarWeekEventBars extends StatelessWidget {
  const CalendarWeekEventBars({
    super.key,
    required this.dates,
    required this.events,
    this.minimumHeight = 0,
    this.headerHeight = 0,
    this.verticalOffset = 0,
    this.categoryColor,
    this.barHeight = 4,
    this.laneHeight = 8,
    this.maxVisibleLanes,
  });

  final List<DateTime?> dates;
  final List<CalendarEvent> events;
  final double minimumHeight;
  final double headerHeight;

  /// 전체 높이는 유지하고 선의 위치만 조정한다. 음수이면 위로 이동한다.
  final double verticalOffset;
  final Color Function(String category)? categoryColor;
  final double barHeight;
  final double laneHeight;
  final int? maxVisibleLanes;

  @override
  Widget build(BuildContext context) {
    final segments = <({CalendarEvent event, int first, int last})>[];
    for (final event in events) {
      final start = event.allDay ? event.start : event.start.toLocal();
      final end = event.allDay ? event.end : event.end.toLocal();
      final lastDate = end.subtract(const Duration(microseconds: 1));
      if (start.year == lastDate.year &&
          start.month == lastDate.month &&
          start.day == lastDate.day) {
        continue;
      }
      final columns = [
        for (var i = 0; i < dates.length; i++)
          if (dates[i] != null && event.occursOn(dates[i]!)) i,
      ];
      if (columns.isNotEmpty) {
        segments.add((event: event, first: columns.first, last: columns.last));
      }
    }
    segments.sort((a, b) {
      final first = a.first.compareTo(b.first);
      if (first != 0) return first;
      final start = a.event.start.compareTo(b.event.start);
      return start != 0 ? start : a.event.id.compareTo(b.event.id);
    });
    final lanes = <List<({CalendarEvent event, int first, int last})>>[];
    for (final segment in segments) {
      final lane = lanes.indexWhere(
        (lane) => lane.every(
          (other) => segment.first > other.last || segment.last < other.first,
        ),
      );
      if (lane < 0) {
        lanes.add([segment]);
      } else {
        lanes[lane].add(segment);
      }
    }
    if (lanes.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columnWidth = constraints.maxWidth / dates.length;
          final visibleCount = maxVisibleLanes == null
              ? lanes.length
              : lanes.length.clamp(0, maxVisibleLanes!);
          final barsHeight = visibleCount * laneHeight;
          // 날짜와 점 아래 공간을 확보하면서 선 묶음을 주 영역 중앙에 둔다.
          final contentHeight = headerHeight * 2 + barsHeight;
          final height = contentHeight > minimumHeight
              ? contentHeight
              : minimumHeight;
          final top = (height - barsHeight) / 2 + verticalOffset;
          return SizedBox(
            height: height,
            child: Stack(
              children: [
                for (var lane = 0; lane < visibleCount; lane++)
                  for (final segment in lanes[lane])
                    Positioned(
                      left: segment.first * columnWidth + 3,
                      top: top + lane * laneHeight + 2,
                      width:
                          (segment.last - segment.first + 1) * columnWidth - 6,
                      height: barHeight,
                      child: Container(
                        key: ValueKey(
                          'calendar-bar:${segment.event.id}:${dates[segment.first]!.toIso8601String()}',
                        ),
                        decoration: BoxDecoration(
                          color: (categoryColor ?? AppColors.calendarCategory)(
                            segment.event.category,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                if (lanes.length > visibleCount)
                  for (var column = 0; column < dates.length; column++)
                    if (lanes
                        .skip(visibleCount)
                        .expand((lane) => lane)
                        .any(
                          (segment) =>
                              column >= segment.first && column <= segment.last,
                        ))
                      Positioned(
                        left: column * columnWidth,
                        top: top + barsHeight + 2,
                        width: columnWidth,
                        child: Text(
                          '+${lanes.skip(visibleCount).expand((lane) => lane).where((segment) => column >= segment.first && column <= segment.last).length}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.calendarStatus,
                          ),
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
