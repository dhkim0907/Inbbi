import 'dart:convert';

import 'package:http/http.dart' as http;

import 'calendar_event.dart';

class GoogleCalendarAuthRequired implements Exception {
  const GoogleCalendarAuthRequired();
}

class GoogleCalendarAccessDenied implements Exception {
  const GoogleCalendarAccessDenied();
}

abstract interface class GoogleCalendarApi {
  Future<GoogleCalendarFetchResult> fetchMonth(DateTime month, String token);
}

class GoogleCalendarFetchResult {
  const GoogleCalendarFetchResult(this.events, this.receivedCount);
  final List<CalendarEvent> events;
  final int receivedCount;
}

class HttpGoogleCalendarApi implements GoogleCalendarApi {
  HttpGoogleCalendarApi({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;

  @override
  Future<GoogleCalendarFetchResult> fetchMonth(
    DateTime month,
    String token,
  ) async {
    final first = DateTime(month.year, month.month, 1).toUtc();
    final next = DateTime(month.year, month.month + 1, 1).toUtc();
    final events = <CalendarEvent>[];
    var receivedCount = 0;
    String? pageToken;
    final seenPageTokens = <String>{};
    for (var page = 0; page < 50; page++) {
      final query = <String, String>{
        'timeMin': first.toIso8601String(),
        'timeMax': next.toIso8601String(),
        'singleEvents': 'true',
        'maxResults': '250',
        'timeZone': 'UTC',
      };
      if (pageToken != null) query['pageToken'] = pageToken;
      final uri = Uri.https(
        'www.googleapis.com',
        '/calendar/v3/calendars/primary/events',
        query,
      );
      final response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401) {
        throw const GoogleCalendarAuthRequired();
      }
      if (response.statusCode == 403) {
        throw const GoogleCalendarAccessDenied();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Google Calendar HTTP ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      for (final raw in body['items'] as List<dynamic>? ?? const []) {
        receivedCount++;
        final event = parseGoogleEvent(Map<String, dynamic>.from(raw as Map));
        if (event != null) events.add(event);
      }
      pageToken = body['nextPageToken'] as String?;
      if (pageToken == null || pageToken.isEmpty) {
        return GoogleCalendarFetchResult(events, receivedCount);
      }
      if (!seenPageTokens.add(pageToken)) {
        throw const FormatException('Repeated Google page token');
      }
    }
    throw const FormatException('Too many Google calendar pages');
  }
}

CalendarEvent? parseGoogleEvent(Map<String, dynamic> value) {
  if (value['status'] == 'cancelled') return null;
  final id = value['id'];
  if (id is! String || id.isEmpty) return null;
  final startValue = value['start'];
  final endValue = value['end'];
  if (startValue is! Map || endValue is! Map) return null;
  final startMap = Map<String, dynamic>.from(startValue);
  final endMap = Map<String, dynamic>.from(endValue);
  final allDay = startMap['date'] is String;
  final start = allDay
      ? CalendarEvent.parseDateOnly(startMap['date'])
      : DateTime.tryParse(startMap['dateTime'] as String? ?? '');
  final end = allDay
      ? CalendarEvent.parseDateOnly(endMap['date'])
      : DateTime.tryParse(endMap['dateTime'] as String? ?? '');
  if (start == null || end == null || !end.isAfter(start)) return null;
  final summary = value['summary'];
  final extended = value['extendedProperties'];
  final private = extended is Map ? extended['private'] : null;
  final category = private is Map ? private['inbbiCategory'] : null;
  return CalendarEvent(
    id: 'google:primary:$id',
    source: CalendarSource.google,
    calendarId: 'primary',
    title: summary is String && summary.trim().isNotEmpty ? summary : '(제목 없음)',
    category: category == '일정' || category == '할일'
        ? category as String
        : 'Google',
    start: start,
    end: end,
    allDay: allDay,
    location: value['location'] as String? ?? '',
    memo: value['description'] as String? ?? '',
  );
}
