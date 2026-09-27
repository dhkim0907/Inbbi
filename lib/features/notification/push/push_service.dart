import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../notification_service.dart';
import 'push_gateway.dart';
import 'push_inbox.dart' as inbox;
import 'push_payload.dart';

abstract interface class PushPreferences {
  Future<bool> loadEnabled();
  Future<void> saveEnabled(bool enabled);
}

class LocalPushPreferences implements PushPreferences {
  final _prefs = SharedPreferencesAsync();
  @override
  Future<bool> loadEnabled() async =>
      await _prefs.getBool('inbbi.push.enabled') ?? false;
  @override
  Future<void> saveEnabled(bool enabled) =>
      _prefs.setBool('inbbi.push.enabled', enabled);
}

class PushService extends ChangeNotifier {
  PushService({
    required this.gateway,
    required this.notifications,
    required this.preferences,
    required this.configured,
    Future<List<Map<String, dynamic>>> Function()? loadInbox,
    Future<void> Function(String)? removeInbox,
  }) : _loadInbox = loadInbox ?? inbox.loadPendingPushes,
       _removeInbox = removeInbox ?? inbox.removePendingPush;
  final PushGateway gateway;
  final NotificationService notifications;
  final PushPreferences preferences;
  final bool configured;
  final Future<List<Map<String, dynamic>>> Function() _loadInbox;
  final Future<void> Function(String) _removeInbox;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final ValueNotifier<AppNotification?> opened = ValueNotifier(null);
  bool initialized = false;
  bool enabled = false;
  bool busy = false;
  bool _disposed = false;
  String? error;
  // 메모리에서만 보유. 개발자가 명시적으로 복사할 때만 클립보드에 전달한다.
  String? _token;
  String? get debugToken => kDebugMode ? _token : null;
  String? get currentToken => enabled ? _token : null;
  PushPermission permission = PushPermission.notDetermined;
  Future<void> _receiving = Future.value();
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (!configured || initialized || busy) return;
    busy = true;
    error = null;
    _emit();
    try {
      await gateway.initialize();
      enabled = await preferences.loadEnabled();
      permission = await gateway.permission();
      _subscriptions.add(
        gateway.messages.listen((data) => receive(data), onError: _streamError),
      );
      _subscriptions.add(
        gateway.openedMessages.listen(
          (data) => receive(data, open: true),
          onError: _streamError,
        ),
      );
      _subscriptions.add(
        gateway.tokenRefresh.listen((value) {
          if (enabled) {
            _token = value;
            _emit();
          }
        }, onError: _streamError),
      );
      _subscriptions.add(inbox.watchPushOpened().listen((_) => syncInbox()));
      initialized = true;
      final initial = await gateway.initialMessage();
      if (initial != null) await receive(initial, open: true);
      await syncInbox();
      if (enabled && permission == PushPermission.allowed) {
        _token = await gateway.enable();
      }
      if (!enabled && permission == PushPermission.allowed) {
        await gateway.disable();
      }
    } catch (_) {
      error = '알림 연결에 실패했어요. 설정과 네트워크를 확인하고 다시 시도해 주세요.';
    } finally {
      busy = false;
      _emit();
    }
  }

  void _streamError(Object _) {
    error = '알림 연결이 끊겼어요. 다시 연결해 주세요.';
    _emit();
  }

  Future<void> setEnabled(bool value) async {
    if (busy || !initialized) return;
    busy = true;
    error = null;
    _emit();
    try {
      if (value) {
        permission = await gateway.permission(request: true);
        if (permission != PushPermission.allowed) {
          error = '알림 권한이 꺼져 있어요. 기기 또는 브라우저 설정에서 허용해 주세요.';
          return;
        }
        _token = await gateway.enable();
        if (_token == null) throw StateError('Missing token');
        try {
          await preferences.saveEnabled(true);
        } catch (_) {
          await gateway.disable();
          _token = null;
          rethrow;
        }
        enabled = true;
      } else {
        await preferences.saveEnabled(false);
        await gateway.disable();
        _token = null;
        enabled = false;
      }
    } catch (_) {
      error = '알림 설정을 적용하지 못했어요. 네트워크를 확인하고 다시 시도해 주세요.';
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> receive(Map<String, dynamic> data, {bool open = false}) {
    final operation = _receiving.then((_) async {
      final item = parsePush(data);
      if (item == null) return;
      await notifications.initialize();
      if (!notifications.accepts(item.kind)) return;
      await notifications.upsert(item);
      if (notifications.error != null) {
        throw StateError('Notification storage failed');
      }
      if (open && !_disposed) opened.value = item;
    });
    _receiving = operation.catchError((Object _) {
      error = '수신한 알림을 저장하지 못했어요. 다시 시도해 주세요.';
      _emit();
    });
    return _receiving;
  }

  Future<void> syncInbox() async {
    try {
      for (final data in await _loadInbox()) {
        final item = parsePush(data);
        if (item == null) continue;
        await receive(data);
        if (notifications.error == null) {
          if (data['_opened'] == true &&
              notifications.accepts(item.kind) &&
              !_disposed) {
            opened.value = item;
          }
          await _removeInbox(item.id);
        }
      }
    } catch (_) {
      error = '보관된 알림을 불러오지 못했어요. 다시 시도해 주세요.';
      _emit();
    }
  }

  Future<void> resume() async {
    if (!initialized || busy) return;
    await syncInbox();
    try {
      permission = await gateway.permission();
    } catch (_) {
      _streamError(StateError('Permission unavailable'));
    }
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    opened.dispose();
    super.dispose();
  }
}
