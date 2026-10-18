import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_calendar_api.dart';
import 'calendar_event.dart';
import 'calendar_event_draft.dart';
import 'google_calendar_api.dart';

class CalendarEventNotFound implements Exception {
  const CalendarEventNotFound();
}

abstract interface class CalendarEventWriter {
  Future<void> delete(String eventId, String token);
  Future<CalendarEvent> create(CalendarEventDraft draft, String token);
  Future<CalendarEvent> update(
    String eventId,
    CalendarEventDraft draft,
    String token,
  );
}

class HttpGoogleCalendarEventWriter implements CalendarEventWriter {
  HttpGoogleCalendarEventWriter({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  static final Uri _events = Uri.https(
    'www.googleapis.com',
    '/calendar/v3/calendars/primary/events',
  );

  @override
  Future<CalendarEvent> create(CalendarEventDraft draft, String token) async {
    final response = await _client
        .post(
          _events,
          headers: _headers(token),
          body: jsonEncode(draft.toGoogleJson()),
        )
        .timeout(const Duration(seconds: 15));
    return _parse(response);
  }

  @override
  Future<CalendarEvent> update(
    String eventId,
    CalendarEventDraft draft,
    String token,
  ) async {
    final rawId = _rawGoogleId(eventId);
    final uri = _events.replace(pathSegments: [..._events.pathSegments, rawId]);
    final response = await _client
        .patch(
          uri,
          headers: _headers(token),
          body: jsonEncode({
            ...draft.toGoogleJson(),
            'location': draft.location,
            'description': draft.memo,
          }),
        )
        .timeout(const Duration(seconds: 15));
    return _parse(response);
  }

  @override
  Future<void> delete(String eventId, String token) async {
    final uri = _events.replace(
      pathSegments: [..._events.pathSegments, _rawGoogleId(eventId)],
    );
    final response = await _client
        .delete(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) throw const GoogleCalendarAuthRequired();
    if (response.statusCode == 403) throw const GoogleCalendarAccessDenied();
    if (response.statusCode == 404 || response.statusCode == 410) {
      throw const CalendarEventNotFound();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Google Calendar HTTP ${response.statusCode}');
    }
  }

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  CalendarEvent _parse(http.Response response) {
    if (response.statusCode == 401) throw const GoogleCalendarAuthRequired();
    if (response.statusCode == 403) throw const GoogleCalendarAccessDenied();
    if (response.statusCode == 404) throw const CalendarEventNotFound();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Google Calendar HTTP ${response.statusCode}');
    }
    final event = parseGoogleEvent(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    if (event == null) throw const FormatException('Invalid Google event');
    return event;
  }
}

class HttpAppCalendarEventWriter implements CalendarEventWriter {
  HttpAppCalendarEventWriter({
    required this.baseUrl,
    http.Client? client,
    this.appOnly = false,
  }) : _client = client ?? http.Client();

  final Uri? baseUrl;
  final bool appOnly;
  final http.Client _client;

  @override
  Future<CalendarEvent> create(CalendarEventDraft draft, String token) async {
    final response = await _client
        .post(
          _events,
          headers: _headers(token),
          body: jsonEncode(
            appOnly ? draft.toAppServerJson() : draft.toServerJson(),
          ),
        )
        .timeout(const Duration(seconds: 15));
    return _parse(response);
  }

  @override
  Future<CalendarEvent> update(
    String eventId,
    CalendarEventDraft draft,
    String token,
  ) async {
    final rawId = _rawServerId(eventId);
    final uri = _events.replace(pathSegments: [..._events.pathSegments, rawId]);
    final response = await _client
        .patch(
          uri,
          headers: _headers(token),
          body: jsonEncode({
            ...(appOnly ? draft.toAppServerJson() : draft.toServerJson()),
            'location': draft.location,
            'description': draft.memo,
          }),
        )
        .timeout(const Duration(seconds: 15));
    return _parse(response);
  }

  @override
  Future<void> delete(String eventId, String token) async {
    final uri = _events.replace(
      pathSegments: [..._events.pathSegments, _rawServerId(eventId)],
    );
    final response = await _client
        .delete(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const CalendarAuthRequired();
    }
    if (response.statusCode == 404) throw const CalendarEventNotFound();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Calendar HTTP ${response.statusCode}');
    }
  }

  Uri get _events {
    final base = baseUrl;
    if (base == null) throw const CalendarUnavailable();
    return base.resolve(
      appOnly ? 'api/v1/calendar/app-events' : 'api/v1/calendar/events',
    );
  }

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  CalendarEvent _parse(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const CalendarAuthRequired();
    }
    if (response.statusCode == 404) throw const CalendarEventNotFound();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Calendar HTTP ${response.statusCode}');
    }
    return parseAppCalendarEvent(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

String _rawGoogleId(String eventId) {
  const prefix = 'google:primary:';
  if (!eventId.startsWith(prefix) || eventId.length == prefix.length) {
    throw ArgumentError.value(eventId, 'eventId', 'Not a primary Google event');
  }
  return eventId.substring(prefix.length);
}

String _rawServerId(String eventId) {
  const prefix = 'server:';
  if (!eventId.startsWith(prefix) || eventId.length == prefix.length) {
    throw ArgumentError.value(eventId, 'eventId', 'Not a server event');
  }
  return eventId.substring(prefix.length);
}
