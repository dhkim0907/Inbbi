import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 홈 대시보드의 미니 캘린더와 캘린더 탭이 공통으로 쓰는 월간 날짜 그리드.
/// 요일 헤더 없이 주 단위 Row만 그린다. [selectedDay]/[onDaySelected]를
/// 넘기지 않으면(둘 다 null) 홈 대시보드처럼 선택 표시나 탭 상호작용 없는
/// 단순 미리보기로 동작한다.
class MonthCalendarGrid extends StatelessWidget {
  const MonthCalendarGrid({
    super.key,
    required this.month,
    required this.eventDays,
    this.selectedDay,
    this.onDaySelected,
  });

  final DateTime month;
  final Set<int> eventDays;
  final int? selectedDay;
  final ValueChanged<int>? onDaySelected;

  static const Color _brandColor = Color(0xFF346CB2);

  List<List<int?>> _buildWeeks() {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = month.weekday - 1;
    final cells = <int?>[
      for (var i = 0; i < leadingBlanks; i++) null,
      for (var d = 1; d <= daysInMonth; d++) d,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
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
            child: Row(
              children: [
                for (final day in week)
                  Expanded(
                    child: day == null
                        ? const SizedBox(height: 32)
                        : _DayCell(
                            day: day,
                            selected: day == selectedDay,
                            hasEvent: eventDays.contains(day),
                            onTap: onDaySelected == null
                                ? null
                                : () => onDaySelected!(day),
                          ),
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
    required this.selected,
    required this.hasEvent,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final bool hasEvent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Text(
          '$day',
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected
                ? MonthCalendarGrid._brandColor
                : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
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
