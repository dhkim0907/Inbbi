import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_calendar_api.dart';

class GoogleServerLinkUnavailable implements Exception {
  const GoogleServerLinkUnavailable();
}

class GoogleServerLinkAuthRequired implements Exception {
  const GoogleServerLinkAuthRequired();
}

abstract interface class GoogleCalendarServerLink {
  bool get configured;
  Future<bool> isConnected();
  Future<void> connect(String authorizationCode);
  Future<void> disconnect();
}

/// One-time Google code is sent only to the authenticated app server.
/// No Google token or code is written to local storage.
class HttpGoogleCalendarServerLink implements GoogleCalendarServerLink {
  HttpGoogleCalendarServerLink({
    required this.baseUrl,
    required this.session,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri? baseUrl;
  final CalendarSession session;
  final http.Client _client;

  @override
  bool get configured => baseUrl != null;

  Uri get _endpoint {
    final base = baseUrl;
    if (base == null) throw const GoogleServerLinkUnavailable();
    return base.resolve('api/v1/calendar/google/connection');
  }

  String get _appToken {
    final token = session.token;
    if (token == null) throw const GoogleServerLinkAuthRequired();
    return token;
  }

  @override
  Future<bool> isConnected() async {
    final response = await _client
        .get(_endpoint, headers: {'Authorization': 'Bearer $_appToken'})
        .timeout(const Duration(seconds: 15));
    _checkResponse(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final connected = body['connected'];
    if (connected is! bool) throw const FormatException('Invalid link status');
    return connected;
  }

  @override
  Future<void> connect(String authorizationCode) async {
    if (authorizationCode.isEmpty) throw const FormatException('Empty code');
    final response = await _client
        .post(
          _endpoint,
          headers: {
            'Authorization': 'Bearer $_appToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'authorizationCode': authorizationCode}),
        )
        .timeout(const Duration(seconds: 15));
    _checkResponse(response);
  }

  @override
  Future<void> disconnect() async {
    final response = await _client
        .delete(_endpoint, headers: {'Authorization': 'Bearer $_appToken'})
        .timeout(const Duration(seconds: 15));
    _checkResponse(response);
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const GoogleServerLinkAuthRequired();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Google server link HTTP ${response.statusCode}');
    }
  }
}
