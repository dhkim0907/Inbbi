import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../notification_service.dart';
import '../push/push_payload.dart';
import 'realtime_transport.dart';

enum RealtimeStatus {
  disconnected,
  connecting,
  authenticating,
  connected,
  authFailed,
  retrying,
}

abstract interface class NotificationCursorStore {
  Future<String?> load(String userId);
  Future<void> save(String userId, String cursor);
}

class LocalNotificationCursorStore implements NotificationCursorStore {
  final _prefs = SharedPreferencesAsync();
  String _key(String userId) =>
      'inbbi.notifications.cursor.${Uri.encodeComponent(userId)}';
  @override
  Future<String?> load(String userId) => _prefs.getString(_key(userId));
  @override
  Future<void> save(String userId, String cursor) =>
      _prefs.setString(_key(userId), cursor);
}

class NotificationRealtimeService extends ChangeNotifier {
  NotificationRealtimeService({
    required this.url,
    required this.api,
    required this.notifications,
    required this.cursorStore,
    required this.openSocket,
  });
  final Uri url;
  final NotificationApi api;
  final NotificationService notifications;
  final NotificationCursorStore cursorStore;
  final NotificationSocket Function(Uri) openSocket;
  RealtimeStatus status = RealtimeStatus.disconnected;
  String? error;
  String? _token;
  String? _deviceId;
  String? _userId;
  String? _fcmToken;
  NotificationSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  Timer? _authTimeout;
  int _attempts = 0;
  int _generation = 0;
  bool _foreground = true;
  bool _disposed = false;
  Future<void> _processing = Future.value();
  Future<void> _syncing = Future.value();
  String? get deviceId => _deviceId;
  bool get active => _token != null;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start({
    required String accessToken,
    required String deviceId,
  }) async {
    if (accessToken.isEmpty || deviceId.isEmpty) {
      throw ArgumentError('인증 정보가 필요합니다.');
    }
    final pushToken = _fcmToken;
    await stop();
    _fcmToken = pushToken;
    _token = accessToken;
    _deviceId = deviceId;
    _foreground = true;
    error = null;
    _connect();
    if (_fcmToken != null) unawaited(updateFcmToken(_fcmToken));
  }

  Future<void> stop() async {
    final oldToken = _token;
    final oldDevice = _deviceId;
    if (oldToken != null && oldDevice != null && _fcmToken != null) {
      try {
        await api.removeToken(oldToken, oldDevice);
      } catch (_) {
        error = '서버 푸시 토큰을 해제하지 못했어요.';
        _emit();
      }
    }
    _token = null;
    _deviceId = null;
    _userId = null;
    _fcmToken = null;
    _foreground = false;
    _generation++;
    _retry?.cancel();
    _authTimeout?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) await socket.close();
    await notifications.activateAccount(null);
    status = RealtimeStatus.disconnected;
    _emit();
  }

  Future<void> suspend() async {
    _foreground = false;
    _generation++;
    _retry?.cancel();
    _authTimeout?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) await socket.close();
    status = RealtimeStatus.disconnected;
    _emit();
  }

  void resume() {
    _foreground = true;
    if (_token != null &&
        _socket == null &&
        status != RealtimeStatus.authFailed) {
      _connect();
    }
  }

  Future<void> reconnect() async {
    if (_token == null || status == RealtimeStatus.authFailed) return;
    await suspend();
    _attempts = 0;
    resume();
  }

  Future<void> refreshCredentials(String accessToken) async {
    final deviceId = _deviceId;
    if (deviceId != null) {
      await start(accessToken: accessToken, deviceId: deviceId);
    }
  }

  Duration get retryDelay =>
      Duration(seconds: min(30, 1 << min(_attempts - 1, 5)));
  void _connect() {
    if (!_foreground || _token == null || _socket != null) return;
    final generation = ++_generation;
    status = RealtimeStatus.connecting;
    _emit();
    try {
      final socket = openSocket(url);
      _socket = socket;
      _subscription = socket.messages.listen(
        (frame) => _enqueue(frame, generation),
        onError: (_) => _lost(generation),
        onDone: () => _lost(generation),
      );
      socket.ready
          .timeout(const Duration(seconds: 10))
          .then((_) {
            if (generation != _generation || !_foreground) return;
            status = RealtimeStatus.authenticating;
            _emit();
            socket.send(
              jsonEncode({
                'type': 'auth',
                'accessToken': _token,
                'deviceId': _deviceId,
              }),
            );
            _authTimeout = Timer(
              const Duration(seconds: 10),
              () => _lost(generation),
            );
          })
          .catchError((Object _) => _lost(generation));
    } catch (_) {
      _lost(generation);
    }
  }

  void _lost(int generation) {
    if (generation != _generation) return;
    _generation++;
    _authTimeout?.cancel();
    final socket = _socket;
    _socket = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (socket != null) unawaited(socket.close());
    if (!_foreground || _token == null) {
      status = RealtimeStatus.disconnected;
      _emit();
      return;
    }
    _attempts++;
    status = RealtimeStatus.retrying;
    error = '실시간 알림 연결이 끊겼어요. 다시 연결합니다.';
    _emit();
    _retry = Timer(retryDelay, _connect);
  }

  void _enqueue(dynamic frame, int generation) {
    _processing = _processing
        .then((_) => _handle(frame, generation))
        .catchError((Object _) {
          error = '알림 메시지를 처리하지 못했어요.';
          _emit();
        });
  }

  Future<void> _handle(dynamic frame, int generation) async {
    if (generation != _generation || frame is! String || frame.length > 32768) {
      return;
    }
    final dynamic parsed;
    try {
      parsed = jsonDecode(frame);
    } catch (_) {
      return;
    }
    if (parsed is! Map) return;
    final message = Map<String, dynamic>.from(parsed);
    if (message['type'] == 'auth.result' &&
        status == RealtimeStatus.authenticating) {
      _authTimeout?.cancel();
      if (message['success'] != true ||
          message['userId'] is! String ||
          (message['userId'] as String).isEmpty) {
        _generation++;
        status = RealtimeStatus.authFailed;
        error = '실시간 알림 인증에 실패했어요. 다시 로그인해 주세요.';
        final socket = _socket;
        _socket = null;
        unawaited(_subscription?.cancel());
        _subscription = null;
        if (socket != null) unawaited(socket.close());
        _emit();
        return;
      }
      final authenticatedUser = message['userId'] as String;
      if (!await notifications.activateAccount(authenticatedUser)) {
        _lost(generation);
        return;
      }
      if (generation != _generation) return;
      _userId = authenticatedUser;
      _attempts = 0;
      status = RealtimeStatus.connected;
      error = null;
      _emit();
      unawaited(syncMissing());
      unawaited(updatePreferences());
      if (_fcmToken != null) unawaited(updateFcmToken(_fcmToken));
      return;
    }
    if (status != RealtimeStatus.connected ||
        message['type'] != 'notification') {
      return;
    }
    final item = parsePush(message);
    if (item == null) return;
    await notifications.initialize();
    if (!await notifications.upsert(item)) return;
    if (generation != _generation) return;
    try {
      _socket?.send(
        jsonEncode({
          'type': 'notification.ack',
          'eventId': item.id,
          'status': 'listed',
          'receivedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (_) {
      _lost(generation);
    }
    final token = _token;
    if (token != null) {
      unawaited(
        api.receipt(token, item.id, 'listed').catchError((Object _) {}),
      );
    }
  }

  Future<void> syncMissing() {
    final result = _syncing.then((_) async {
      final token = _token, userId = _userId;
      if (token == null || userId == null) return;
      try {
        var cursor = await cursorStore.load(userId);
        for (var pageNumber = 0; pageNumber < 50; pageNumber++) {
          final page = await api.fetch(token, cursor);
          if (token != _token || userId != _userId) return;
          for (final raw in page.items) {
            final item = parsePush(raw);
            if (item == null) {
              throw const FormatException('Invalid notification');
            }
            await notifications.initialize();
            if (!await notifications.upsert(item)) {
              throw StateError('Notification storage failed');
            }
          }
          final next = page.nextCursor;
          if (next == null || next.isEmpty || next == cursor) return;
          await cursorStore.save(userId, next);
          cursor = next;
        }
        throw StateError('Too many pages');
      } catch (_) {
        error = '누락 알림을 불러오지 못했어요. 재접속 시 다시 시도합니다.';
        _emit();
      }
    });
    _syncing = result;
    return result;
  }

  Future<void> sendReceipt(String eventId, String receiptStatus) async {
    final token = _token;
    if (token == null) return;
    try {
      await api.receipt(token, eventId, receiptStatus);
    } catch (_) {
      error = '알림 확인 결과를 서버에 전달하지 못했어요.';
      _emit();
    }
  }

  Future<void> updatePreferences() async {
    final token = _token;
    if (token == null || _userId == null) return;
    try {
      await api.updatePreferences(
        token,
        notifications.selectedKinds.map((kind) => kind.name).toList(),
      );
    } catch (_) {
      error = '외부 알림 종류 설정을 서버에 전달하지 못했어요.';
      _emit();
    }
  }

  Future<void> updateFcmToken(String? token) async {
    _fcmToken = token;
    final accessToken = _token, deviceId = _deviceId;
    if (accessToken == null || deviceId == null) {
      return;
    }
    try {
      if (token == null) {
        await api.removeToken(accessToken, deviceId);
      } else {
        await api.registerToken(accessToken, deviceId, token);
      }
    } catch (_) {
      error = '푸시 토큰을 서버에 등록하지 못했어요.';
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
