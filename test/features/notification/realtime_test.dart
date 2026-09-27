import 'package:inbbi/features/notification/push/push_service.dart';
import 'push_service_test.dart' show FakeGateway, FakePreferences;
import 'package:flutter/material.dart';
import 'package:inbbi/features/notification/realtime/realtime_scope.dart';
import 'package:inbbi/features/notification/realtime/realtime_settings_card.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inbbi/features/notification/notification_service.dart';
import 'package:inbbi/features/notification/push/push_payload.dart';
import 'package:inbbi/features/notification/realtime/realtime_service.dart';
import 'package:inbbi/features/notification/realtime/realtime_transport.dart';
import 'notification_service_test.dart' show MemoryStorage;

Map<String, dynamic> notice(String id, int version, {String title = '공지'}) => {
  'type': 'notification',
  'eventId': id,
  'eventType': 'notice.created',
  'version': version,
  'title': title,
  'body': '본문',
  'target': {'type': 'notice', 'id': 'n-1'},
  'deepLink': '/notices/n-1',
  'occurredAt': '2026-09-27T02:10:00Z',
};

class FakeSocket implements NotificationSocket {
  final controller = StreamController<dynamic>.broadcast();
  final sent = <Map<String, dynamic>>[];
  bool closed = false;
  @override
  Future<void> get ready async {}
  @override
  Stream<dynamic> get messages => controller.stream;
  @override
  void send(String text) =>
      sent.add(Map<String, dynamic>.from(jsonDecode(text) as Map));
  void emit(Map<String, dynamic> message) =>
      controller.add(jsonEncode(message));
  @override
  Future<void> close() async {
    closed = true;
    await controller.close();
  }
}

class FakeApi implements NotificationApi {
  final pages = <String?, NotificationPageResult>{};
  final fetched = <String?>[];
  final receipts = <String>[];
  final tokens = <String>[];
  final preferenceUpdates = <List<String>>[];
  bool fail = false;
  @override
  Future<NotificationPageResult> fetch(
    String accessToken,
    String? cursor,
  ) async {
    fetched.add(cursor);
    if (fail) throw StateError('offline');
    return pages[cursor] ?? const NotificationPageResult([], null);
  }

  @override
  Future<void> receipt(
    String accessToken,
    String eventId,
    String status,
  ) async => receipts.add('$eventId:$status');
  @override
  Future<void> registerToken(
    String accessToken,
    String deviceId,
    String token,
  ) async => tokens.add('$deviceId:registered');
  @override
  Future<void> removeToken(String accessToken, String deviceId) async =>
      tokens.add('$deviceId:removed');
  @override
  Future<void> updatePreferences(
    String accessToken,
    List<String> kinds,
  ) async => preferenceUpdates.add(List.of(kinds));
}

class FakeCursor implements NotificationCursorStore {
  final values = <String, String>{};
  @override
  Future<String?> load(String userId) async => values[userId];
  @override
  Future<void> save(String userId, String cursor) async {
    values[userId] = cursor;
  }
}

Future<void> flush() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('FCM 문자열 페이로드와 알 수 없는 종류는 안전하게 목록으로 이동', () {
    final fcm = {
      ...notice('e1', 3),
      'version': '3',
      'target': '{"type":"notice","id":"n-1"}',
    };
    final item = parsePush(fcm)!;
    expect(item.version, 3);
    expect(item.destinationIndex, 2);
    expect(
      parsePush({
        ...notice('e2', 1),
        'eventType': 'other.created',
      })!.destinationIndex,
      5,
    );
    expect(parsePush({...notice('e3', 1), 'occurredAt': 'invalid'}), isNull);
    expect(parsePush({...notice('e4', 1), 'target': 'not-json'}), isNull);
  });
  test('버전 역전과 중복 전송에도 읽음 상태와 최신 내용 유지', () async {
    final service = NotificationService(MemoryStorage());
    await service.initialize();
    await service.upsert(parsePush(notice('e1', 1))!);
    await service.markRead('e1');
    await service.upsert(parsePush(notice('e1', 3, title: '수정'))!);
    await service.upsert(parsePush(notice('e1', 2, title: '오래됨'))!);
    await service.upsert(parsePush(notice('e1', 3, title: '중복'))!);
    expect(service.items.single.title, '수정');
    expect(service.items.single.version, 3);
    expect(service.unreadCount, 0);
    final restored = NotificationService(service.storage);
    await restored.initialize();
    expect(restored.items.single.version, 3);
  });
  test('인증 전 차단, ACK와 REST receipt, 목록 cursor 복원, 재접속', () async {
    final notifications = NotificationService(MemoryStorage());
    await notifications.initialize();
    final api = FakeApi();
    api.pages[null] = NotificationPageResult([notice('missed', 1)], 'next');
    api.pages['next'] = const NotificationPageResult([], null);
    final cursor = FakeCursor();
    final sockets = <FakeSocket>[];
    final service = NotificationRealtimeService(
      url: Uri.parse('wss://test.example/ws'),
      api: api,
      notifications: notifications,
      cursorStore: cursor,
      openSocket: (_) {
        final socket = FakeSocket();
        sockets.add(socket);
        return socket;
      },
    );
    await service.start(accessToken: 'fake-token', deviceId: 'device-test');
    await flush();
    final socket = sockets.single;
    expect(socket.sent.single['type'], 'auth');
    socket.emit(notice('before-auth', 1));
    await flush();
    expect(notifications.items, isEmpty);
    socket.emit({
      'type': 'auth.result',
      'success': true,
      'userId': 'test-user',
    });
    await flush();
    expect(cursor.values['test-user'], 'next');
    expect(
      api.preferenceUpdates.single.toSet(),
      NotificationKind.values.map((kind) => kind.name).toSet(),
    );
    expect(notifications.items.single.id, 'missed');
    socket.emit(notice('live', 1));
    await flush();
    expect(notifications.items.length, 2);
    expect(socket.sent.last['type'], 'notification.ack');
    expect(socket.sent.last['status'], 'listed');
    expect(api.receipts, contains('live:listed'));
    await service.updateFcmToken('fake-fcm');
    expect(api.tokens.last, 'device-test:registered');
    socket.emit(notice('live', 2, title: '최신'));
    await flush();
    expect(notifications.items.where((e) => e.id == 'live').single.version, 2);
    await service.suspend();
    expect(socket.closed, true);
    service.resume();
    await flush();
    expect(sockets.length, 2);
    sockets.last.emit({
      'type': 'auth.result',
      'success': true,
      'userId': 'test-user',
    });
    await flush();
    expect(api.fetched.last, 'next');
    await service.stop();
    expect(api.tokens.last, 'device-test:removed');
    service.dispose();
  });
  test('WebSocket과 FCM의 동일 ID 버전은 한 항목으로 합쳐짐', () async {
    final notifications = NotificationService(MemoryStorage());
    await notifications.initialize();
    final sockets = <FakeSocket>[];
    final realtime = NotificationRealtimeService(
      url: Uri.parse('wss://test.example/ws'),
      api: FakeApi(),
      notifications: notifications,
      cursorStore: FakeCursor(),
      openSocket: (_) {
        final socket = FakeSocket();
        sockets.add(socket);
        return socket;
      },
    );
    final push = PushService(
      gateway: FakeGateway(),
      notifications: notifications,
      preferences: FakePreferences(),
      configured: false,
      loadInbox: () async => [],
      removeInbox: (_) async {},
    );
    await realtime.start(accessToken: 'fake', deviceId: 'device');
    await flush();
    sockets.single.emit({
      'type': 'auth.result',
      'success': true,
      'userId': 'test-user',
    });
    await flush();
    sockets.single.emit(notice('shared', 1));
    await flush();
    await notifications.markRead('shared');
    await push.receive({
      ...notice('shared', 1),
      'version': '1',
      'target': '{"type":"notice","id":"n-1"}',
    });
    await push.receive({
      ...notice('shared', 2, title: '수정된 공지'),
      'version': '2',
      'target': '{"type":"notice","id":"n-1"}',
    });
    sockets.single.emit(notice('shared', 1, title: '오래된 WebSocket'));
    await flush();
    expect(notifications.items.length, 1);
    expect(notifications.items.single.version, 2);
    expect(notifications.items.single.title, '수정된 공지');
    expect(notifications.items.single.isRead, true);
    await realtime.stop();
    realtime.dispose();
    push.dispose();
  });
  test('WebSocket 인증 대기 중에도 REST 푸시 토큰 등록', () async {
    final api = FakeApi();
    final service = NotificationRealtimeService(
      url: Uri.parse('wss://test.example/ws'),
      api: api,
      notifications: NotificationService(MemoryStorage()),
      cursorStore: FakeCursor(),
      openSocket: (_) => FakeSocket(),
    );
    await service.start(accessToken: 'fake', deviceId: 'device');
    await service.updateFcmToken('fcm-token');
    expect(api.tokens, contains('device:registered'));
    await service.stop();
    service.dispose();
  });
  test('인증 실패 시 재접속하지 않음', () async {
    final sockets = <FakeSocket>[];
    final notifications = NotificationService(MemoryStorage());
    final service = NotificationRealtimeService(
      url: Uri.parse('wss://test.example/ws'),
      api: FakeApi(),
      notifications: notifications,
      cursorStore: FakeCursor(),
      openSocket: (_) {
        final s = FakeSocket();
        sockets.add(s);
        return s;
      },
    );
    await service.start(accessToken: 'bad-token', deviceId: 'device');
    await flush();
    sockets.single.emit({
      'type': 'auth.result',
      'success': false,
      'errorCode': 'INVALID_TOKEN',
    });
    await flush();
    expect(service.status, RealtimeStatus.authFailed);
    expect(sockets.length, 1);
    service.resume();
    await flush();
    expect(sockets.length, 1);
    await service.stop();
    service.dispose();
  });
  test('계정 전환 시 서로 다른 알림 목록을 복원', () async {
    final stores = <String?, MemoryStorage>{};
    NotificationStorage storageFor(String? userId) =>
        stores.putIfAbsent(userId, MemoryStorage.new);
    final service = NotificationService(
      storageFor(null),
      accountStorage: storageFor,
    );
    await service.initialize();
    await service.upsert(parsePush(notice('anonymous', 1))!);
    expect(await service.activateAccount('alice'), true);
    expect(service.items, isEmpty);
    await service.upsert(parsePush(notice('alice-event', 1))!);
    expect(await service.activateAccount('bob'), true);
    expect(service.items, isEmpty);
    expect(await service.activateAccount('alice'), true);
    expect(service.items.single.id, 'alice-event');
    expect(await service.activateAccount(null), true);
    expect(service.items.single.id, 'anonymous');
  });
  test('소켓 종료 후 1초, 다시 실패하면 2초 재접속', () async {
    final sockets = <FakeSocket>[];
    final service = NotificationRealtimeService(
      url: Uri.parse('wss://test.example/ws'),
      api: FakeApi(),
      notifications: NotificationService(MemoryStorage()),
      cursorStore: FakeCursor(),
      openSocket: (_) {
        final socket = FakeSocket();
        sockets.add(socket);
        return socket;
      },
    );
    await service.start(accessToken: 'fake', deviceId: 'device');
    await flush();
    await sockets.first.controller.close();
    await flush();
    expect(service.retryDelay, const Duration(seconds: 1));
    expect(service.status, RealtimeStatus.retrying);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(sockets.length, 2);
    await sockets.last.controller.close();
    await flush();
    expect(service.retryDelay, const Duration(seconds: 2));
    await service.stop();
    service.dispose();
  });
  test('목록 실패 시 커서를 진행하지 않고 재연결 후 복구', () async {
    final sockets = <FakeSocket>[];
    final api = FakeApi()..fail = true;
    api.pages[null] = NotificationPageResult([
      notice('restored', 1),
    ], 'cursor-1');
    final cursor = FakeCursor();
    final notifications = NotificationService(MemoryStorage());
    final service = NotificationRealtimeService(
      url: Uri.parse('wss://test.example/ws'),
      api: api,
      notifications: notifications,
      cursorStore: cursor,
      openSocket: (_) {
        final socket = FakeSocket();
        sockets.add(socket);
        return socket;
      },
    );
    await service.start(accessToken: 'fake', deviceId: 'device');
    await flush();
    sockets.last.emit({
      'type': 'auth.result',
      'success': true,
      'userId': 'account',
    });
    await flush();
    expect(cursor.values['account'], isNull);
    api.fail = false;
    await service.reconnect();
    await flush();
    sockets.last.emit({
      'type': 'auth.result',
      'success': true,
      'userId': 'account',
    });
    await flush();
    expect(notifications.items.single.id, 'restored');
    expect(cursor.values['account'], 'cursor-1');
    await service.stop();
    service.dispose();
  });
  for (final width in [390.0, 840.0, 1280.0]) {
    testWidgets('실시간 연결 설정 레이아웃 너비 $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = NotificationRealtimeService(
        url: Uri.parse('wss://test.example/ws'),
        api: FakeApi(),
        notifications: NotificationService(MemoryStorage()),
        cursorStore: FakeCursor(),
        openSocket: (_) => FakeSocket(),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(
        RealtimeScope(
          service: service,
          child: const MaterialApp(
            home: Scaffold(body: RealtimeSettingsCard()),
          ),
        ),
      );
      expect(find.text('테스트 서버 실시간 알림'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test('HTTP 목록·receipt·토큰 API는 인증과 커서를 전달', () async {
    final seen = <http.Request>[];
    final client = MockClient((request) async {
      seen.add(request);
      if (request.url.path.endsWith('/notifications')) {
        return http.Response(
          jsonEncode({
            'items': [notice('api', 1)],
            'nextCursor': null,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{}', 200);
    });
    final api = HttpNotificationApi(
      Uri.parse('https://test.example/'),
      client: client,
    );
    final result = await api.fetch('fake-access', 'cursor-1');
    expect(result.items.single['eventId'], 'api');
    expect(seen.single.url.queryParameters['cursor'], 'cursor-1');
    await api.receipt('fake-access', 'event-1', 'opened');
    await api.registerToken('fake-access', 'device-1', 'fake-fcm');
    await api.removeToken('fake-access', 'device-1');
    await api.updatePreferences('fake-access', ['deadline', 'notice']);
    expect(
      seen.every(
        (request) => request.headers['Authorization'] == 'Bearer fake-access',
      ),
      true,
    );
    expect(seen.last.method, 'PUT');
    expect(seen.last.url.path, '/api/v1/notification-preferences');
    expect(jsonDecode(seen.last.body), {
      'enabledKinds': ['deadline', 'notice'],
    });
  });
}
