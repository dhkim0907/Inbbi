/// Input accepted by both the app-server and Google event writers.
/// [end] is exclusive, including for all-day events.
enum CalendarSaveTarget { appOnly, googleCalendar }

class CalendarEventDraft {
  CalendarEventDraft({
    required String title,
    required this.start,
    required this.end,
    required this.allDay,
    this.category = 'Google',
    this.saveTarget = CalendarSaveTarget.googleCalendar,
    String location = '',
    String memo = '',
  }) : title = title.trim(),
       location = location.trim(),
       memo = memo.trim() {
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
  final String category;
  final String location;
  final String memo;
  final CalendarSaveTarget saveTarget;

  String get startValue =>
      allDay ? _date(start) : start.toUtc().toIso8601String();
  String get endValue => allDay ? _date(end) : end.toUtc().toIso8601String();

  Map<String, Object> toServerJson() => {
    'title': title,
    'category': category,
    'calendarId': 'primary',
    'allDay': allDay,
    'start': startValue,
    'end': endValue,
    if (location.isNotEmpty) 'location': location,
    if (memo.isNotEmpty) 'description': memo,
  };

  /// 앱 전용 API는 Google 대상 정보를 보내지 않는다.
  Map<String, Object> toAppServerJson() => {
    'title': title,
    'category': category,
    'allDay': allDay,
    'start': startValue,
    'end': endValue,
    if (location.isNotEmpty) 'location': location,
    if (memo.isNotEmpty) 'description': memo,
  };

  Map<String, Object> toGoogleJson() => {
    'summary': title,
    'start': {allDay ? 'date' : 'dateTime': startValue},
    'end': {allDay ? 'date' : 'dateTime': endValue},
    if (location.isNotEmpty) 'location': location,
    if (memo.isNotEmpty) 'description': memo,
    if (category == '일정' || category == '할일')
      'extendedProperties': {
        'private': {'inbbiCategory': category},
      },
  };

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
