enum CalendarSource { appServer, google }

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.source,
    required this.title,
    required this.category,
    required this.start,
    required this.end,
    required this.allDay,
    this.calendarId,
    this.isCompleted = false,
    this.location = '',
    this.memo = '',
  });

  final String id;
  final CalendarSource source;
  final String title;
  final String category;
  final DateTime start;

  /// Exclusive end. For all-day events, both dates are UTC date-only values.
  final DateTime end;
  final bool allDay;
  final String? calendarId;
  final bool isCompleted;
  final String location;
  final String memo;

  bool occursOn(DateTime day) {
    final first = allDay
        ? DateTime.utc(day.year, day.month, day.day)
        : DateTime(day.year, day.month, day.day);
    final next = allDay
        ? DateTime.utc(day.year, day.month, day.day + 1)
        : DateTime(day.year, day.month, day.day + 1);
    final eventStart = allDay ? start : start.toLocal();
    final eventEnd = allDay ? end : end.toLocal();
    return eventStart.isBefore(next) && eventEnd.isAfter(first);
  }

  bool overlapsMonth(DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    for (var day = 1; day <= lastDay; day++) {
      if (occursOn(DateTime(month.year, month.month, day))) return true;
    }
    return false;
  }

  static DateTime? parseDateOnly(Object? value) {
    if (value is! String) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    final date = DateTime.utc(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }
}
