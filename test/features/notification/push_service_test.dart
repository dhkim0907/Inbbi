import 'package:inbbi/core/widgets/main_tab_shell.dart';
import 'package:inbbi/features/calendar/app_calendar_api.dart';
import 'package:inbbi/features/calendar/calendar_controller.dart';
import 'package:inbbi/features/calendar/calendar_scope.dart';
import 'package:inbbi/features/calendar/google_calendar_api.dart';
import 'package:inbbi/features/calendar/google_calendar_auth.dart';
import 'package:inbbi/features/notification/notification_scope.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/features/notification/push/push_gateway.dart';
import 'package:inbbi/features/notification/push/push_payload.dart';
import 'package:inbbi/features/notification/push/push_service.dart';
import 'package:inbbi/features/notification/push/push_scope.dart';
import 'package:inbbi/features/notification/push/push_settings_card.dart';
import 'package:inbbi/features/notification/notification_service.dart';
import 'notification_service_test.dart' show MemoryStorage;

Map<String, dynamic> payload([String id = 'event-1']) => {
  'eventId': id,
  'title': '서버 알림',
  'body': '일정 마감 안내',
  'kind': 'deadline',
  'createdAt': '2026-09-27T01:00:00Z',
};

class FakeGateway implements PushGateway {
  final incoming = StreamController<Map<String, dynamic>>.broadcast();
  final taps = StreamController<Map<String, dynamic>>.broadcast();
  final tokens = StreamController<String>.broadcast();
  PushPermission status = PushPermission.allowed;
  Map<String, dynamic>? initial;
  bool fail = false;
  int disableCalls = 0;
  @override
  Future<void> initialize() async {
    if (fail) throw StateError('fail');
  }

  @override
  Stream<Map<String, dynamic>> get messages => incoming.stream;
  @override
  Stream<Map<String, dynamic>> get openedMessages => taps.stream;
  @override
  Stream<String> get tokenRefresh => tokens.stream;
  @override
  Future<Map<String, dynamic>?> initialMessage() async => initial;
  @override
  Future<PushPermission> permission({bool request = false}) async => status;
  @override
  Future<String?> enable() async {
    if (fail) throw StateError('fail');
    return 'fake-token';
  }

  @override
  Future<void> disable() async {
    if (fail) throw StateError('fail');
    disableCalls++;
  }
}

class FakePreferences implements PushPreferences {
  bool value = false;
  @override
  Future<bool> loadEnabled() async => value;
  @override
  Future<void> saveEnabled(bool enabled) async {
    value = enabled;
  }
}

void main() {
  late FakeGateway gateway;
  late FakePreferences prefs;
  late NotificationService notifications;
  late MemoryStorage storage;
  late PushService service;
  late List<Map<String, dynamic>> pending;
  setUp(() {
    gateway = FakeGateway();
    prefs = FakePreferences();
    storage = MemoryStorage();
    notifications = NotificationService(storage);
    pending = [];
    service = PushService(
      gateway: gateway,
      notifications: notifications,
      preferences: prefs,
      configured: true,
      loadInbox: () async => [...pending],
      removeInbox: (id) async =>
          pending.removeWhere((item) => item['eventId'] == id),
    );
  });
  tearDown(() async {
    service.dispose();
    notifications.dispose();
    await gateway.incoming.close();
    await gateway.taps.close();
    await gateway.tokens.close();
  });
  test('권한 거부 후 허용, 토큰 갱신 및 끄기', () async {
    gateway.status = PushPermission.denied;
    await service.initialize();
    await service.setEnabled(true);
    expect(service.enabled, false);
    expect(service.error, isNotNull);
    gateway.status = PushPermission.allowed;
    await service.setEnabled(true);
    expect(service.enabled, true);
    expect(prefs.value, true);
    gateway.tokens.add('renewed-fake-token');
    await Future<void>.delayed(Duration.zero);
    expect(service.debugToken, 'renewed-fake-token');
    await service.setEnabled(false);
    expect(service.enabled, false);
    expect(prefs.value, false);
    expect(service.debugToken, isNull);
    expect(gateway.disableCalls, 1);
  });
  test('초기 알림 클릭과 수신 중복 방지, 읽음 유지', () async {
    gateway.initial = payload();
    await service.initialize();
    expect(service.opened.value?.destinationIndex, 1);
    expect(notifications.items.length, 1);
    await notifications.markRead('event-1');
    await service.receive(payload());
    expect(notifications.unreadCount, 0);
    expect(notifications.items.length, 1);
  });
  test('백그라운드 수신함 저장 실패 시 유지하고 재시도', () async {
    pending.add({...payload(), '_opened': true});
    storage.fail = true;
    await service.initialize();
    expect(pending.length, 1);
    storage.fail = false;
    await service.syncInbox();
    expect(pending, isEmpty);
    expect(notifications.items.length, 1);
    expect(service.opened.value?.id, 'event-1');
  });
  test('연결 실패 복구와 비활성화 실패 표시', () async {
    gateway.fail = true;
    await service.initialize();
    expect(service.initialized, false);
    gateway.fail = false;
    await service.initialize();
    await service.setEnabled(true);
    gateway.fail = true;
    await service.setEnabled(false);
    expect(service.error, isNotNull);
    expect(service.enabled, true);
    gateway.fail = false;
    await service.setEnabled(false);
    expect(service.enabled, false);
  });
  test('유효하지 않은 메시지와 임의 화면 이동을 거부', () async {
    expect(parsePush({'eventId': 'a', 'route': '/admin'}), isNull);
    expect(parsePush({...payload(), 'kind': 'unknown'}), isNull);
    expect(parsePush({...payload(), 'createdAt': 'invalid'}), isNull);
    await service.receive({'eventId': 'invalid'});
    expect(notifications.items, isEmpty);
  });
  testWidgets('로그인 후 메인 셸에서 보류된 클릭을 소비하고 읽음 처리', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    gateway.initial = payload();
    await tester.runAsync(service.initialize);
    final calendarSession = CalendarSession();
    final calendar = CalendarController(
      appApi: HttpAppCalendarApi(baseUrl: null, session: calendarSession),
      session: calendarSession,
      googleAuth: GoogleSignInCalendarAuth(),
      googleApi: HttpGoogleCalendarApi(),
    );
    addTearDown(calendar.dispose);
    await tester.pumpWidget(
      CalendarScope(
        controller: calendar,
        child: NotificationScope(
          service: notifications,
          child: PushScope(
            service: service,
            child: const MaterialApp(home: MainTabShell()),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);
    expect(service.opened.value, isNull);
    expect(notifications.unreadCount, 0);
    expect(tester.takeException(), isNull);
  });
  for (final width in [390.0, 840.0, 1280.0]) {
    testWidgets('외부 알림 설정 너비 $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await service.initialize();
      await tester.pumpWidget(
        PushScope(
          service: service,
          child: const MaterialApp(home: Scaffold(body: PushSettingsCard())),
        ),
      );
      expect(find.text('앱 외부 알림'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
      expect(service.enabled, true);
      expect(find.text('테스트 수신 토큰 복사'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
