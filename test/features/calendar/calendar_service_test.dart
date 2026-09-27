import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inbbi/features/calendar/app_calendar_api.dart';
import 'package:inbbi/features/calendar/calendar_controller.dart';
import 'package:inbbi/features/calendar/calendar_event.dart';
import 'package:inbbi/features/calendar/calendar_page.dart';
import 'package:inbbi/features/calendar/calendar_scope.dart';
import 'package:inbbi/features/settings/settings_page.dart';
import 'package:inbbi/features/home/home_dashboard_page.dart';
import 'package:inbbi/core/widgets/month_calendar_grid.dart';
import 'package:inbbi/features/calendar/google_calendar_api.dart';
import 'package:inbbi/features/calendar/google_calendar_auth.dart';
import 'package:inbbi/features/notification/notification_scope.dart';
import 'package:inbbi/features/notification/notification_service.dart';

class _NotificationStorage implements NotificationStorage {
  @override
  Future<String?> load() async => null;
  @override
  Future<void> save(String value) async {}
}

class _AppApi implements AppCalendarApi {
  List<CalendarEvent> events = [];
  bool fail = false;
  @override
  Future<List<CalendarEvent>> fetchMonth(DateTime month) async {
    if (fail) throw StateError('offline');
    return events;
  }
}

class _GoogleApi implements GoogleCalendarApi {
  List<CalendarEvent> events = [];
  bool fail = false;
  String? lastToken;
  @override
  Future<GoogleCalendarFetchResult> fetchMonth(
    DateTime month,
    String token,
  ) async {
    if (fail) throw StateError('offline');
    lastToken = token;
    return GoogleCalendarFetchResult(events, events.length);
  }
}

class _Auth implements GoogleCalendarAuth {
  GoogleCalendarAccount? account;
  @override
  bool get configured => true;
  @override
  bool get needsWebButton => false;
  @override
  Stream<GoogleCalendarAccount?> get changes => const Stream.empty();
  @override
  Future<GoogleCalendarAccount?> restore() async => account;
  @override
  Future<GoogleCalendarAccount?> connect() async => account;
  @override
  Future<String?> accessToken({bool interactive = false}) async =>
      account == null ? null : 'test-token';
  @override
  Future<void> disconnect() async => account = null;
}

class _InteractiveAuth extends _Auth {
  int interactiveRequests = 0;
  @override
  Future<String?> accessToken({bool interactive = false}) async {
    if (!interactive) return null;
    interactiveRequests++;
    return 'newly-authorized-token';
  }
}

void main() {
  test('앱 서버 일정의 종일 종료 날짜는 포함하지 않는다', () {
    final event = parseAppCalendarEvent({
      'id': 's1',
      'title': '시험',
      'category': '학사',
      'allDay': true,
      'start': '2026-09-27',
      'end': '2026-09-29',
    });
    expect(event.occursOn(DateTime(2026, 9, 27)), true);
    expect(event.occursOn(DateTime(2026, 9, 28)), true);
    expect(event.occursOn(DateTime(2026, 9, 29)), false);
    expect(
      () => parseAppCalendarEvent({
        'id': 'bad',
        'title': '시간대 없음',
        'allDay': false,
        'start': '2026-09-27T09:00:00',
        'end': '2026-09-27T10:00:00',
      }),
      throwsFormatException,
    );
  });

  test('앱 서버 API는 인증과 커서를 전달해 모든 페이지를 읽는다', () async {
    final requests = <http.Request>[];
    final api = HttpAppCalendarApi(
      baseUrl: Uri.parse('https://calendar.example/'),
      session: CalendarSession()..setToken('test-token'),
      client: MockClient((request) async {
        requests.add(request);
        final cursor = request.url.queryParameters['cursor'];
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': cursor == null ? 'a' : 'b',
                'title': '일정',
                'category': '과제',
                'start': '2026-09-27T10:00:00+09:00',
                'end': '2026-09-27T11:00:00+09:00',
                'allDay': false,
              },
            ],
            'nextCursor': cursor == null ? 'next' : null,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final events = await api.fetchMonth(DateTime(2026, 9));
    expect(events.map((event) => event.id), ['server:a', 'server:b']);
    expect(requests.last.url.queryParameters['cursor'], 'next');
    expect(
      requests.every(
        (request) => request.headers['Authorization'] == 'Bearer test-token',
      ),
      true,
    );
  });

  test('앱 서버 인증 거부는 별도 상태로 분류한다', () async {
    final api = HttpAppCalendarApi(
      baseUrl: Uri.parse('https://calendar.example/'),
      session: CalendarSession()..setToken('expired'),
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    await expectLater(
      api.fetchMonth(DateTime(2026, 9)),
      throwsA(isA<CalendarAuthRequired>()),
    );
  });

  test('앱 서버 미설정은 캘린더 오류로 표시하지 않는다', () async {
    final session = CalendarSession();
    final controller = CalendarController(
      appApi: HttpAppCalendarApi(baseUrl: null, session: session),
      session: session,
      googleAuth: _Auth(),
      googleApi: _GoogleApi(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.appError, isNull);
    expect(controller.appLoaded, false);
  });

  test('Google 종일 일정과 취소된 일정 변환', () {
    final event = parseGoogleEvent({
      'id': 'g1',
      'summary': '휴일',
      'start': {'date': '2026-09-27'},
      'end': {'date': '2026-09-28'},
    })!;
    expect(event.source, CalendarSource.google);
    expect(event.occursOn(DateTime(2026, 9, 27)), true);
    expect(event.occursOn(DateTime(2026, 9, 28)), false);
    expect(parseGoogleEvent({'id': 'g2', 'status': 'cancelled'}), isNull);
  });

  test('Google API는 반복 일정 인스턴스와 모든 페이지를 조회한다', () async {
    final requests = <http.Request>[];
    final api = HttpGoogleCalendarApi(
      client: MockClient((request) async {
        requests.add(request);
        final page = request.url.queryParameters['pageToken'];
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': page == null ? 'g1' : 'g2',
                'summary': '수업',
                'start': {'dateTime': '2026-09-27T01:00:00Z'},
                'end': {'dateTime': '2026-09-27T02:00:00Z'},
              },
            ],
            'nextPageToken': page == null ? 'second' : null,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final result = await api.fetchMonth(DateTime(2026, 9), 'test-token');
    expect(result.receivedCount, 2);
    expect(result.events.map((event) => event.id), [
      'google:primary:g1',
      'google:primary:g2',
    ]);
    expect(requests.first.url.queryParameters['singleEvents'], 'true');
    expect(requests.last.url.queryParameters['pageToken'], 'second');
    expect(
      requests.every(
        (request) => request.headers['Authorization'] == 'Bearer test-token',
      ),
      true,
    );
  });

  test('Google API의 403은 토큰 만료와 구분한다', () async {
    final api = HttpGoogleCalendarApi(
      client: MockClient((_) async => http.Response('{}', 403)),
    );
    await expectLater(
      api.fetchMonth(DateTime(2026, 9), 'test-token'),
      throwsA(isA<GoogleCalendarAccessDenied>()),
    );
  });

  test('Google 실패 시 앱 서버 일정은 유지하고 연결 해제 시 Google만 제거', () async {
    final app = _AppApi()
      ..events = [
        CalendarEvent(
          id: 'server:a',
          source: CalendarSource.appServer,
          title: '서버 일정',
          category: '과제',
          start: DateTime(2026, 9, 27, 9),
          end: DateTime(2026, 9, 27, 10),
          allDay: false,
        ),
      ];
    final google = _GoogleApi()
      ..events = [
        CalendarEvent(
          id: 'google:primary:b',
          source: CalendarSource.google,
          title: 'Google 일정',
          category: 'Google',
          start: DateTime(2026, 9, 27, 11),
          end: DateTime(2026, 9, 27, 12),
          allDay: false,
        ),
      ];
    final auth = _Auth()
      ..account = const GoogleCalendarAccount('user', 'test@example.com');
    final controller = CalendarController(
      appApi: app,
      session: CalendarSession(),
      googleAuth: auth,
      googleApi: google,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.setMonth(DateTime(2026, 9));
    expect(controller.events.length, 2);
    google.fail = true;
    await controller.refreshGoogle();
    expect(controller.events.length, 2);
    expect(controller.googleError, isNotNull);
    google.fail = false;
    app.fail = true;
    await controller.refreshApp();
    expect(controller.events.length, 2);
    expect(controller.appError, isNotNull);
    await controller.disconnectGoogle();
    expect(controller.events.map((event) => event.id), ['server:a']);
  });

  test('권한 승인 직후 받은 토큰으로 Google 일정을 조회한다', () async {
    final auth = _InteractiveAuth()
      ..account = const GoogleCalendarAccount('user', 'test@example.com');
    final google = _GoogleApi()
      ..events = [
        CalendarEvent(
          id: 'google:primary:event',
          source: CalendarSource.google,
          title: '내 일정',
          category: 'Google',
          start: DateTime(2026, 9, 27, 9),
          end: DateTime(2026, 9, 27, 10),
          allDay: false,
        ),
      ];
    final controller = CalendarController(
      appApi: _AppApi(),
      session: CalendarSession(),
      googleAuth: auth,
      googleApi: google,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.setMonth(DateTime(2026, 9));
    expect(controller.googleAuthorizationRequired, true);
    await controller.authorizeGoogle();
    expect(auth.interactiveRequests, 1);
    expect(google.lastToken, 'newly-authorized-token');
    expect(controller.events.single.title, '내 일정');
    expect(controller.googleAuthorizationRequired, false);
  });

  for (final width in [390.0, 839.0, 840.0, 1280.0]) {
    testWidgets('캘린더 화면 너비 $width에서 서버 일정 표시', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = _AppApi()
        ..events = [
          CalendarEvent(
            id: 'server:one',
            source: CalendarSource.appServer,
            title: '서버 일정',
            category: '과제',
            start: DateTime(2026, 9, 27, 9),
            end: DateTime(2026, 9, 27, 10),
            allDay: false,
          ),
        ];
      final controller = CalendarController(
        appApi: app,
        session: CalendarSession(),
        googleAuth: _Auth(),
        googleApi: _GoogleApi(),
      );
      addTearDown(controller.dispose);
      final notifications = NotificationService(_NotificationStorage());
      addTearDown(notifications.dispose);
      await notifications.initialize();
      await controller.initialize();
      await controller.setMonth(DateTime(2026, 9));
      await tester.pumpWidget(
        NotificationScope(
          service: notifications,
          child: CalendarScope(
            controller: controller,
            child: const MaterialApp(home: CalendarPage()),
          ),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('27'));
      await tester.tap(find.text('27'));
      await tester.pump();
      expect(find.text('서버 일정'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('홈 미니 캘린더가 같은 서버 일정 날짜를 사용한다', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _AppApi()
      ..events = [
        CalendarEvent(
          id: 'server:home',
          source: CalendarSource.appServer,
          title: '홈 일정',
          category: '과제',
          start: DateTime.utc(2026, 9, 18),
          end: DateTime.utc(2026, 9, 19),
          allDay: true,
        ),
      ];
    final controller = CalendarController(
      appApi: app,
      session: CalendarSession(),
      googleAuth: _Auth(),
      googleApi: _GoogleApi(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.setMonth(DateTime(2026, 9));
    final notifications = NotificationService(_NotificationStorage());
    addTearDown(notifications.dispose);
    await notifications.initialize();
    await tester.pumpWidget(
      CalendarScope(
        controller: controller,
        child: NotificationScope(
          service: notifications,
          child: const MaterialApp(home: HomeDashboardPage()),
        ),
      ),
    );
    final grid = tester.widget<MonthCalendarGrid>(
      find.byType(MonthCalendarGrid),
    );
    expect(grid.month.month, 9);
    expect(grid.eventDays, contains(18));
    expect(tester.takeException(), isNull);
  });

  for (final width in [430.0, 840.0]) {
    testWidgets('기존 Google 설정 행 너비 $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = CalendarController(
        appApi: _AppApi(),
        session: CalendarSession(),
        googleAuth: _Auth(),
        googleApi: _GoogleApi(),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      final notifications = NotificationService(_NotificationStorage());
      addTearDown(notifications.dispose);
      await notifications.initialize();
      await tester.pumpWidget(
        CalendarScope(
          controller: controller,
          child: NotificationScope(
            service: notifications,
            child: const MaterialApp(home: SettingsPage()),
          ),
        ),
      );
      expect(find.text('Google Calendar 연동'), findsOneWidget);
      expect(find.text('연동하기'), findsNothing);
      expect(find.text('Google 로그인'), findsOneWidget);
      expect(find.text('테스트 일정 서버'), findsNothing);
      expect(find.text('앱 외부 알림'), findsNothing);
      expect(find.text('받을 알림 종류'), findsNothing);
      expect(find.text('테스트 서버 실시간 알림'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('설정에서 Google 일정 권한을 요청해 일정을 조회한다', (tester) async {
    final auth = _InteractiveAuth()
      ..account = const GoogleCalendarAccount('user', 'test@example.com');
    final google = _GoogleApi();
    final controller = CalendarController(
      appApi: _AppApi(),
      session: CalendarSession(),
      googleAuth: auth,
      googleApi: google,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    final notifications = NotificationService(_NotificationStorage());
    addTearDown(notifications.dispose);
    await notifications.initialize();
    await tester.pumpWidget(
      CalendarScope(
        controller: controller,
        child: NotificationScope(
          service: notifications,
          child: const MaterialApp(home: SettingsPage()),
        ),
      ),
    );
    expect(find.text('일정 권한 허용'), findsOneWidget);
    await tester.tap(find.text('일정 권한 허용'));
    await tester.pumpAndSettle();
    expect(google.lastToken, 'newly-authorized-token');
    expect(controller.googleAuthorizationRequired, false);
  });
}
