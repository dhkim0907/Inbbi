import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

abstract interface class NotificationSocket {
  Future<void> get ready;
  Stream<dynamic> get messages;
  void send(String text);
  Future<void> close();
}

class ChannelNotificationSocket implements NotificationSocket {
  ChannelNotificationSocket(Uri url) : _channel = WebSocketChannel.connect(url);
  final WebSocketChannel _channel;
  @override
  Future<void> get ready => _channel.ready;
  @override
  Stream<dynamic> get messages => _channel.stream;
  @override
  void send(String text) => _channel.sink.add(text);
  @override
  Future<void> close() => _channel.sink.close(status.goingAway);
}

abstract interface class NotificationApi {
  Future<NotificationPageResult> fetch(String accessToken, String? cursor);
  Future<void> receipt(String accessToken, String eventId, String status);
  Future<void> registerToken(String accessToken, String deviceId, String token);
  Future<void> removeToken(String accessToken, String deviceId);
  Future<void> updatePreferences(String accessToken, List<String> kinds);
}

class NotificationPageResult {
  const NotificationPageResult(this.items, this.nextCursor);
  final List<Map<String, dynamic>> items;
  final String? nextCursor;
}

class HttpNotificationApi implements NotificationApi {
  HttpNotificationApi(this.baseUrl, {http.Client? client})
    : _client = client ?? http.Client();
  final Uri baseUrl;
  final http.Client _client;
  Uri _path(String path, [Map<String, String>? query]) =>
      baseUrl.resolve(path).replace(queryParameters: query);
  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };
  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('HTTP ${response.statusCode}');
    }
  }

  @override
  Future<NotificationPageResult> fetch(
    String accessToken,
    String? cursor,
  ) async {
    final response = await _client
        .get(
          _path(
            'api/v1/notifications',
            cursor == null ? null : {'cursor': cursor},
          ),
          headers: _headers(accessToken),
        )
        .timeout(const Duration(seconds: 10));
    _check(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    return NotificationPageResult(items, data['nextCursor'] as String?);
  }

  @override
  Future<void> receipt(
    String accessToken,
    String eventId,
    String status,
  ) async {
    final response = await _client
        .post(
          _path(
            'api/v1/notifications/${Uri.encodeComponent(eventId)}/receipts',
          ),
          headers: _headers(accessToken),
          body: jsonEncode({
            'status': status,
            'receivedAt': DateTime.now().toUtc().toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 10));
    _check(response);
  }

  @override
  Future<void> registerToken(
    String accessToken,
    String deviceId,
    String token,
  ) async {
    final response = await _client
        .put(
          _path('api/v1/devices/${Uri.encodeComponent(deviceId)}/fcm-token'),
          headers: _headers(accessToken),
          body: jsonEncode({'token': token}),
        )
        .timeout(const Duration(seconds: 10));
    _check(response);
  }

  @override
  Future<void> removeToken(String accessToken, String deviceId) async {
    final response = await _client
        .delete(
          _path('api/v1/devices/${Uri.encodeComponent(deviceId)}/fcm-token'),
          headers: _headers(accessToken),
        )
        .timeout(const Duration(seconds: 10));
    _check(response);
  }

  @override
  Future<void> updatePreferences(String accessToken, List<String> kinds) async {
    final response = await _client
        .put(
          _path('api/v1/notification-preferences'),
          headers: _headers(accessToken),
          body: jsonEncode({'enabledKinds': kinds}),
        )
        .timeout(const Duration(seconds: 10));
    _check(response);
  }
}
