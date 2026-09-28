/// Input accepted by both the app-server and Google event writers.
/// [end] is exclusive, including for all-day events.
class CalendarEventDraft {
  CalendarEventDraft({
    required String title,
    required this.start,
    required this.end,
    required this.allDay,
  }) : title = title.trim() {
    if (this.title.isEmpty) throw ArgumentError.value(title, 'title');
    if (!end.isAfter(start)) throw ArgumentError.value(end, 'end');
    if (allDay &&
        (start.hour != 0 ||
            start.minute != 0 ||
            start.second != 0 ||
            start.millisecond != 0 ||
            start.microsecond != 0 ||
            end.hour != 0 ||
            end.minute != 0 ||
            end.second != 0 ||
            end.millisecond != 0 ||
            end.microsecond != 0)) {
      throw ArgumentError('All-day dates must be midnight');
    }
  }

  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;

  String get startValue =>
      allDay ? _date(start) : start.toUtc().toIso8601String();
  String get endValue => allDay ? _date(end) : end.toUtc().toIso8601String();

  Map<String, Object> toServerJson() => {
    'title': title,
    'category': 'Google',
    'calendarId': 'primary',
    'allDay': allDay,
    'start': startValue,
    'end': endValue,
  };

  Map<String, Object> toGoogleJson() => {
    'summary': title,
    'start': {allDay ? 'date' : 'dateTime': startValue},
    'end': {allDay ? 'date' : 'dateTime': endValue},
  };

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
