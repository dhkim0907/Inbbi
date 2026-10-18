import 'calendar_event.dart';

class CalendarEventPresentation {
  const CalendarEventPresentation({required this.event, required this.now});

  final CalendarEvent event;
  final DateTime now;

  bool get hasDeadline => const ['강의', '과제', '할일'].contains(event.category);

  DateTime get _deadline => event.allDay
      ? DateTime(event.end.year, event.end.month, event.end.day)
      : event.end.toLocal();

  bool get isOverdue =>
      hasDeadline && !event.isCompleted && !now.isBefore(_deadline);

  String get statusLabel => event.isCompleted
      ? '완료'
      : isOverdue
      ? '미완료 · 기한 지남'
      : '미완료';

  String get timeLabel {
    if (hasDeadline) {
      final deadline = event.allDay
          ? _deadline.subtract(const Duration(minutes: 1))
          : _deadline;
      final date = _sameDay(deadline, now) ? '' : '${_date(deadline)} ';
      return '마감 $date${_time(deadline)}';
    }
    if (event.allDay) return '종일';
    final start = event.start.toLocal();
    final end = event.end.toLocal();
    final startDate = _sameDay(start, now) ? '' : '${_date(start)} ';
    final endDate = _sameDay(start, end) ? '' : '${_date(end)} ';
    return '$startDate${_time(start)}~ $endDate${_time(end)}';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _date(DateTime date) => '${date.month}/${date.day}';

  String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
