import 'dart:convert';

import 'package:http/http.dart' as http;

import 'calendar_event.dart';

class CalendarUnavailable implements Exception {
  const CalendarUnavailable();
}

class CalendarAuthRequired implements Exception {
  const CalendarAuthRequired();
}

abstract interface class AppCalendarApi {
  Future<List<CalendarEvent>> fetchMonth(DateTime month);
}

/// 로그인 계층이 준비되면 setToken을 호출한다. 토큰은 메모리에서만 보관한다.
class CalendarSession {
  String? _token;
  String? get token => _token;
  void setToken(String? value) =>
      _token = value?.trim().isEmpty == true ? null : value?.trim();
}

class HttpAppCalendarApi implements AppCalendarApi {
  HttpAppCalendarApi({
    required this.baseUrl,
    required this.session,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri? baseUrl;
  final CalendarSession session;
  final http.Client _client;

  @override
  Future<List<CalendarEvent>> fetchMonth(DateTime month) async {
    final base = baseUrl;
    if (base == null) throw const CalendarUnavailable();
    final token = session.token;
    if (token == null) throw const CalendarAuthRequired();
    final first = DateTime(month.year, month.month, 1).toUtc();
    final next = DateTime(month.year, month.month + 1, 1).toUtc();
    final events = <CalendarEvent>[];
    String? cursor;
    final seenCursors = <String>{};
    for (var page = 0; page < 50; page++) {
      final query = <String, String>{
        'timeMin': first.toIso8601String(),
        'timeMax': next.toIso8601String(),
      };
      if (cursor != null) query['cursor'] = cursor;
      final uri = base
          .resolve('api/v1/calendar/events')
          .replace(queryParameters: query);
      final response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const CalendarAuthRequired();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Calendar HTTP ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      for (final raw in body['items'] as List<dynamic>? ?? const []) {
        events.add(
          parseAppCalendarEvent(Map<String, dynamic>.from(raw as Map)),
        );
      }
      cursor = body['nextCursor'] as String?;
      if (cursor == null || cursor.isEmpty) return events;
      if (!seenCursors.add(cursor)) {
        throw const FormatException('Repeated cursor');
      }
    }
    throw const FormatException('Too many calendar pages');
  }
}

CalendarEvent parseAppCalendarEvent(Map<String, dynamic> value) {
  final id = value['id'];
  final title = value['title'];
  final allDay = value['allDay'];
  final startValue = value['start'];
  final endValue = value['end'];
  if (id is! String ||
      id.isEmpty ||
      title is! String ||
      startValue is! String ||
      endValue is! String ||
      allDay is! bool) {
    throw const FormatException('Invalid calendar event');
  }
  if (!allDay && (!_hasOffset(startValue) || !_hasOffset(endValue))) {
    throw const FormatException('Calendar time zone offset required');
  }
  final start = allDay
      ? CalendarEvent.parseDateOnly(startValue)
      : DateTime.tryParse(startValue);
  final end = allDay
      ? CalendarEvent.parseDateOnly(endValue)
      : DateTime.tryParse(endValue);
  if (start == null || end == null || !end.isAfter(start)) {
    throw const FormatException('Invalid calendar event date');
  }
  return CalendarEvent(
    id: 'server:$id',
    source: CalendarSource.appServer,
    title: title,
    category: value['category'] as String? ?? '기타',
    start: start,
    end: end,
    allDay: allDay,
  );
}

bool _hasOffset(String value) =>
    value.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(value);
