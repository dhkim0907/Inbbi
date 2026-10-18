import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../features/calendar/calendar_event.dart';
import 'calendar_week_event_bars.dart';

/// 홈 대시보드의 미니 캘린더와 캘린더 탭이 공통으로 쓰는 월간 날짜 그리드.
/// 요일 헤더 없이 주 단위 Row만 그린다. [selectedDay]/[onDaySelected]를
/// 넘기지 않으면(둘 다 null) 홈 대시보드처럼 선택 표시나 탭 상호작용 없는
/// 단순 미리보기로 동작한다.
class MonthCalendarGrid extends StatelessWidget {
  const MonthCalendarGrid({
    super.key,
    required this.month,
    required this.eventDays,
    this.events,
    this.selectedDay,
    this.onDaySelected,
    this.showNextMonthDays = false,
  });

  final DateTime month;
  final Set<int> eventDays;
  final List<CalendarEvent>? events;
  final int? selectedDay;
  final ValueChanged<int>? onDaySelected;

  /// 월말의 빈 칸에 다음 달 날짜를 표시한다. 선택 콜백에는 현재 월 기준으로
  /// 월 일수를 초과하는 값을 전달하므로 DateTime 생성자로 날짜를 정규화한다.
  final bool showNextMonthDays;

  static const Color _brandColor = Color(0xFF346CB2);

  List<List<int?>> _buildWeeks() {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = DateTime(month.year, month.month).weekday - 1;
    final cells = <int?>[
      for (var i = 0; i < leadingBlanks; i++) null,
      for (var d = 1; d <= daysInMonth; d++) d,
    ];
    while (cells.length % 7 != 0) {
      cells.add(showNextMonthDays ? cells.length - leadingBlanks + 1 : null);
    }
    return [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final week in _buildWeeks())
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Row(
                  children: [
                    for (final day in week)
                      Expanded(
                        child: day == null
                            ? const SizedBox(height: 32)
                            : _DayCell(
                                day: DateTime(month.year, month.month, day).day,
                                outsideMonth:
                                    DateTime(
                                      month.year,
                                      month.month,
                                      day,
                                    ).month !=
                                    month.month,
                                selected: day == selectedDay,
                                hasEvent: eventDays.contains(day),
                                events: events
                                    ?.where(
                                      (event) => event.occursOn(
                                        DateTime(month.year, month.month, day),
                                      ),
                                    )
                                    .toList(),
                                onTap: onDaySelected == null
                                    ? null
                                    : () => onDaySelected!(day),
                              ),
                      ),
                  ],
                ),
                if (events != null)
                  CalendarWeekEventBars(
                    dates: [
                      for (final day in week)
                        day == null
                            ? null
                            : DateTime(month.year, month.month, day),
                    ],
                    events: events!,
                    headerHeight: 32,
                    verticalOffset: -2,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.outsideMonth,
    required this.selected,
    required this.hasEvent,
    this.events,
    required this.onTap,
  });

  final int day;
  final bool outsideMonth;
  final bool selected;
  final bool hasEvent;
  final List<CalendarEvent>? events;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Center(
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected
                  ? MonthCalendarGrid._brandColor
                  : outsideMonth
                  ? AppColors.calendarStatus.withValues(alpha: 0.6)
                  : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (events != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final event in events!.take(4))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: event.isCompleted
                          ? AppColors.calendarCategory(event.category)
                          : Colors.transparent,
                      border: Border.all(
                        color: AppColors.calendarCategory(event.category),
                      ),
                    ),
                  ),
                ),
            ],
          )
        else
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasEvent
                  ? MonthCalendarGrid._brandColor
                  : Colors.transparent,
            ),
          ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: content,
    );
  }
}
