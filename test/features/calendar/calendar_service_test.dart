import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inbbi/features/calendar/app_calendar_api.dart';
import 'package:inbbi/features/calendar/calendar_controller.dart';
import 'package:inbbi/features/calendar/calendar_event.dart';
import 'package:inbbi/features/calendar/calendar_design.dart';
import 'package:inbbi/features/calendar/calendar_event_draft.dart';
import 'package:inbbi/features/calendar/calendar_event_writer.dart';
import 'package:inbbi/features/calendar/calendar_page.dart';
import 'package:inbbi/features/calendar/calendar_scope.dart';
import 'package:inbbi/features/calendar/calendar_sample_events.dart';
import 'package:inbbi/features/settings/settings_page.dart';
import 'package:inbbi/features/home/home_dashboard_page.dart';
import 'package:inbbi/core/widgets/month_calendar_grid.dart';
import 'package:inbbi/core/widgets/calendar_week_event_bars.dart';
import 'package:inbbi/features/calendar/google_calendar_api.dart';
import 'package:inbbi/features/calendar/google_calendar_auth.dart';
import 'package:inbbi/features/calendar/google_calendar_server_link.dart';
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
  Future<String?> serverAuthorizationCode() async =>
      account == null ? null : 'test-server-code';
  @override
  Future<void> disconnect() async => account = null;
}

class _ServerLink implements GoogleCalendarServerLink {
  String? receivedCode;
  bool disconnected = false;
  @override
  bool get configured => true;
  @override
  Future<bool> isConnected() async => receivedCode != null && !disconnected;
  @override
  Future<void> connect(String authorizationCode) async =>
      receivedCode = authorizationCode;
  @override
  Future<void> disconnect() async => disconnected = true;
}

class _RecordingWriter implements CalendarEventWriter {
  @override
  Future<void> delete(String eventId, String token) async {
    calls.add('delete:$eventId:$token');
  }

  final calls = <String>[];
  @override
  Future<CalendarEvent> create(CalendarEventDraft draft, String token) async {
    calls.add('create:$token');
    return CalendarEvent(
      id: 'server:created',
      source: CalendarSource.appServer,
      title: draft.title,
      category: draft.category,
      location: draft.location,
      memo: draft.memo,
      start: draft.start,
      end: draft.end,
      allDay: draft.allDay,
    );
  }

  @override
  Future<CalendarEvent> update(
    String eventId,
    CalendarEventDraft draft,
    String token,
  ) async {
    calls.add('update:$eventId:$token');
    return create(draft, token);
  }
}

class _SavingWriter extends _RecordingWriter {
  _SavingWriter(this.app);
  final _AppApi app;
  @override
  Future<CalendarEvent> create(CalendarEventDraft draft, String token) async {
    final event = await super.create(draft, token);
    app.events.add(event);
    return event;
  }
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

class _OneClickAuth extends _Auth {
  final accountChanges = StreamController<GoogleCalendarAccount?>.broadcast();

  @override
  Stream<GoogleCalendarAccount?> get changes => accountChanges.stream;

  @override
  Future<GoogleCalendarAccount?> connect() async {
    account = const GoogleCalendarAccount('user', 'test@example.com');
    accountChanges.add(account);
    return account;
  }
}

void main() {
  for (final width in [390.0, 840.0, 1280.0]) {
    testWidgets('종류별 샘플 일정 표시와 새로고침 너비 $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final today = DateTime.now();
      final controller = CalendarController(
        appApi: _AppApi(),
        session: CalendarSession(),
        googleAuth: _Auth(),
        googleApi: _GoogleApi(),
        sampleEvents: (month) =>
            calendarSampleEvents(month, referenceDate: today),
      );
      addTearDown(controller.dispose);
      final notifications = NotificationService(_NotificationStorage());
      addTearDown(notifications.dispose);
      await notifications.initialize();
      await controller.initialize();
      await controller.refresh();
      expect(controller.events, hasLength(10));
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
      expect(find.text('[샘플] 자료구조 강의'), findsWidgets);
      expect(find.byKey(const ValueKey('calendar-empty-state')), findsNothing);
      final bars = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('calendar-bar:'),
      );
      expect(bars, findsWidgets);
      for (final element in bars.evaluate()) {
        final line = find.byKey(element.widget.key!);
        final week = find
            .ancestor(
              of: find.ancestor(
                of: line,
                matching: find.byType(CalendarWeekEventBars),
              ),
              matching: find.byType(Stack),
            )
            .last;
        // Figma의 기간 막대는 날짜/상태 점 아래, 주 영역 안에 배치된다.
        expect(
          tester.getRect(line).top,
          greaterThan(tester.getRect(week).top + 40),
        );
        expect(
          tester.getRect(line).bottom,
          lessThanOrEqualTo(tester.getRect(week).bottom),
        );
      }
      await tester.tap(find.widgetWithText(ActionChip, '과제'));
      await tester.pump();
      expect(bars, findsNothing);
      expect(tester.takeException(), isNull);
      await controller.setMonth(DateTime(today.year, today.month + 1));
      await controller.refresh();
      expect(controller.events, hasLength(10));
      expect(
        controller.events.every(
          (event) => event.overlapsMonth(controller.month),
        ),
        isTrue,
      );
    });
  }

  if (kIsWeb) {
    testWidgets('설정의 한 번의 연결 동작으로 Google 일정을 조회한다', (tester) async {
      final auth = _OneClickAuth();
      addTearDown(auth.accountChanges.close);
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
      await tester.tap(find.text('Google Calendar 연결'));
      await tester.pumpAndSettle();
      expect(google.lastToken, 'test-token');
      expect(find.text('일정 권한 허용'), findsNothing);
    });
  }

  test('서버 연결 중 생성·수정은 앱 인증으로 전달한다', () async {
    final serverWriter = _RecordingWriter();
    final directWriter = _RecordingWriter();
    final session = CalendarSession()..setToken('app-session');
    final controller = CalendarController(
      appApi: _AppApi(),
      session: session,
      googleAuth: _Auth(),
      googleApi: _GoogleApi(),
      appWriter: serverWriter,
      googleWriter: directWriter,
    )..serverLinked = true;
    addTearDown(controller.dispose);
    final draft = CalendarEventDraft(
      title: '시험',
      start: DateTime.utc(2026, 9, 27, 9),
      end: DateTime.utc(2026, 9, 27, 10),
      allDay: false,
    );
    await controller.createGoogleEvent(draft);
    await controller.updateGoogleEvent('server:created', draft);
    expect(serverWriter.calls, [
      'create:app-session',
      'update:server:created:app-session',
      'create:app-session',
    ]);
    expect(directWriter.calls, isEmpty);
  });
  test('앱 인증이 있을 때만 Google 서버 코드를 연결한다', () async {
    final auth = _Auth()
      ..account = const GoogleCalendarAccount('id', 'test@example.com');
    final session = CalendarSession();
    final server = _ServerLink();
    final controller = CalendarController(
      appApi: _AppApi(),
      session: session,
      googleAuth: auth,
      googleApi: _GoogleApi(),
      serverLink: server,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.connectGoogleToServer();
    expect(server.receivedCode, isNull);
    session.setToken('app-session');
    await controller.connectGoogleToServer();
    expect(server.receivedCode, 'test-server-code');
    expect(controller.serverLinked, true);
    await controller.disconnectGoogleFromServer();
    expect(server.disconnected, true);
  });

  test('다음 로그인에서 서버 연결을 복원하고 Google 직접 조회를 합치지 않는다', () async {
    final server = _ServerLink()..receivedCode = 'previous-code';
    final session = CalendarSession();
    final app = _AppApi()
      ..events = [
        CalendarEvent(
          id: 'server:google',
          source: CalendarSource.appServer,
          title: '서버 일정',
          category: 'Google',
          start: DateTime(2026, 9, 27),
          end: DateTime(2026, 9, 28),
          allDay: true,
        ),
      ];
    final controller = CalendarController(
      appApi: app,
      session: session,
      googleAuth: _Auth(),
      googleApi: _GoogleApi(),
      serverLink: server,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    controller.setAppToken('new-session');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.serverLinked, true);
    expect(controller.events.map((event) => event.id), ['server:google']);
  });
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

  for (final linked in [false, true]) {
    test('앱 전용 저장은 Google 연결 여부와 무관하게 앱 전용 서비스만 사용한다 $linked', () async {
      final app = _AppApi();
      final appOnlyWriter = _SavingWriter(app);
      final googleWriter = _RecordingWriter();
      final serverGoogleWriter = _RecordingWriter();
      final controller = CalendarController(
        appApi: app,
        session: CalendarSession()..setToken('test-app-token'),
        googleAuth: _Auth(),
        googleApi: _GoogleApi(),
        appOnlyWriter: appOnlyWriter,
        appWriter: serverGoogleWriter,
        googleWriter: googleWriter,
      )..serverLinked = linked;
      addTearDown(controller.dispose);
      await controller.setMonth(DateTime(2026, 10));
      await controller.createEvent(
        CalendarEventDraft(
          title: '앱 전용',
          category: '일정',
          start: DateTime(2026, 10, 9, 9),
          end: DateTime(2026, 10, 9, 10),
          allDay: false,
          saveTarget: CalendarSaveTarget.appOnly,
        ),
      );
      expect(appOnlyWriter.calls, ['create:test-app-token']);
      expect(serverGoogleWriter.calls, isEmpty);
      expect(googleWriter.calls, isEmpty);
      expect(controller.events.single.title, '앱 전용');
    });
  }

  test('앱 전용 저장은 앱 로그인 없이 저장하거나 Google로 대체하지 않는다', () async {
    final writer = _RecordingWriter();
    final controller = CalendarController(
      appApi: _AppApi(),
      session: CalendarSession(),
      googleAuth: _Auth(),
      googleApi: _GoogleApi(),
      appOnlyWriter: writer,
    );
    addTearDown(controller.dispose);
    await expectLater(
      controller.createEvent(
        CalendarEventDraft(
          title: '앱 전용',
          start: DateTime(2026, 10, 9, 9),
          end: DateTime(2026, 10, 9, 10),
          allDay: false,
          saveTarget: CalendarSaveTarget.appOnly,
        ),
      ),
      throwsA(isA<CalendarAuthRequired>()),
    );
    expect(writer.calls, isEmpty);
  });

  for (final target in CalendarSaveTarget.values) {
    for (final width in [390.0, 840.0, 1280.0]) {
      testWidgets('일정 추가 버튼에서 저장 후 캘린더 반영 $target 너비 $width', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final app = _AppApi();
        final writer = _SavingWriter(app);
        final appOnlyWriter = _SavingWriter(app);
        final controller = CalendarController(
          appApi: app,
          session: CalendarSession()..setToken('test-token'),
          googleAuth: _Auth(),
          googleApi: _GoogleApi(),
          appWriter: writer,
          appOnlyWriter: appOnlyWriter,
        )..serverLinked = true;
        addTearDown(controller.dispose);
        final notifications = NotificationService(_NotificationStorage());
        addTearDown(notifications.dispose);
        await notifications.initialize();
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
        await tester.pumpAndSettle();
        final button = find.byType(FloatingActionButton);
        expect(button, findsOneWidget);
        expect(
          tester.widget<FloatingActionButton>(button).shape,
          isA<CircleBorder>(),
        );
        final position = tester.getRect(button);
        expect(position.right, greaterThan(width - 40));
        expect(position.bottom, greaterThan(950));
        await tester.tap(find.text('15'));
        await tester.pump();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('2026-09-15'), findsNWidgets(2));
        await tester.enterText(
          find.byKey(const ValueKey('calendar-event-title')),
          '새 일정',
        );
        final option = find.byKey(const ValueKey('calendar-event-google-save'));
        await tester.ensureVisible(option);
        final google = target == CalendarSaveTarget.googleCalendar;
        if (tester.widget<Checkbox>(option).value != google) {
          await tester.tap(option);
          await tester.pump();
        }
        await tester.tap(find.text('저장'));
        await tester.pumpAndSettle();
        expect(
          target == CalendarSaveTarget.appOnly
              ? appOnlyWriter.calls
              : writer.calls,
          ['create:test-token'],
        );
        expect(
          target == CalendarSaveTarget.appOnly
              ? writer.calls
              : appOnlyWriter.calls,
          isEmpty,
        );
        expect(app.events.single.start, DateTime(2026, 9, 15, 9));
        expect(find.text('새 일정'), findsOneWidget);
        expect(find.text('일정을 저장했어요.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [390.0, 839.0, 840.0, 1280.0]) {
    for (final month in [DateTime(2026, 9), DateTime(2026, 12)]) {
      testWidgets('다음 달 날짜 표시와 선택 $month 너비 $width', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final nextDate = DateTime(month.year, month.month + 1, 2);
        final controller = CalendarController(
          appApi: _AppApi()
            ..events = [
              CalendarEvent(
                id: 'next-month',
                source: CalendarSource.appServer,
                title: '다음 달 일정',
                category: '일정',
                start: nextDate,
                end: nextDate.add(const Duration(hours: 1)),
                allDay: false,
              ),
            ],
          session: CalendarSession(),
          googleAuth: _Auth(),
          googleApi: _GoogleApi(),
        );
        addTearDown(controller.dispose);
        final notifications = NotificationService(_NotificationStorage());
        addTearDown(notifications.dispose);
        await notifications.initialize();
        await controller.setMonth(month);
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
        final nextDay = find
            .descendant(
              of: find.byKey(const ValueKey('calendar-month-card')),
              matching: find.text('2'),
            )
            .last;
        final currentDay = find
            .descendant(
              of: find.byKey(const ValueKey('calendar-month-card')),
              matching: find.text('2'),
            )
            .first;
        expect(
          tester.widget<Text>(nextDay).style!.color!.a,
          lessThan(tester.widget<Text>(currentDay).style!.color!.a),
        );
        await tester.ensureVisible(nextDay);
        await tester.tap(nextDay);
        await tester.pumpAndSettle();
        expect(controller.month, DateTime(nextDate.year, nextDate.month));
        expect(find.textContaining('${nextDate.month}월 2일'), findsOneWidget);
        expect(find.text('다음 달 일정'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [390.0, 839.0, 840.0, 1280.0]) {
    testWidgets('완료 상태 범례와 일정 색상 너비 $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = CalendarController(
        appApi: _AppApi()
          ..events = [
            for (final completed in [false, true])
              CalendarEvent(
                id: 'status:$completed',
                source: CalendarSource.appServer,
                title: '상태 일정 $completed',
                category: '일정',
                start: DateTime(2026, 9, 15, 9),
                end: DateTime(2026, 9, 15, 10),
                allDay: false,
                isCompleted: completed,
              ),
          ],
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
      expect(find.text('미완료'), findsOneWidget);
      expect(find.text('완료'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('calendar-empty-state')),
        findsOneWidget,
      );
      expect(find.text('표시할 일정이 없어요.'), findsOneWidget);
      expect(find.text('오른쪽 아래 + 버튼으로 일정이나 할일을 추가해보세요.'), findsOneWidget);
      expect(find.text('미완료 강의·과제·할일'), findsOneWidget);
      expect(find.text('0개'), findsOneWidget);
      expect(find.text('해당 기간에 미완료 항목이 없어요.'), findsOneWidget);
      final decorations = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byKey(const ValueKey('calendar-month-card')),
              matching: find.byType(Container),
            ),
          )
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .where(
            (decoration) =>
                decoration.border is Border &&
                (decoration.border! as Border).top.color ==
                    CalendarDesign.category('일정'),
          );
      expect(
        decorations.any((decoration) => decoration.color == Colors.transparent),
        true,
      );
      expect(
        decorations.any(
          (decoration) => decoration.color == CalendarDesign.category('일정'),
        ),
        true,
      );
      final day14 = tester.getCenter(find.text('14')).dx;
      final day15 = tester.getCenter(find.text('15')).dx;
      final day16 = tester.getCenter(find.text('16')).dx;
      expect(day15, closeTo((day14 + day16) / 2, 0.01));
      expect(find.byType(ActionChip), findsNWidgets(5));
      for (final entry in {
        '강의': CalendarDesign.brand,
        '과제': CalendarDesign.brand,
        '일정': CalendarDesign.brand,
        '할일': CalendarDesign.brand,
      }.entries) {
        final chip = find.widgetWithText(ActionChip, entry.key);
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pump();
        expect(tester.widget<ActionChip>(chip).backgroundColor, entry.value);
        final ink = tester.widget<Ink>(
          find.descendant(of: chip, matching: find.byType(Ink)).first,
        );
        expect((ink.decoration! as ShapeDecoration).color, entry.value);
      }
      await tester.tap(find.widgetWithText(ActionChip, '전체'));
      await tester.pump();
      await tester.ensureVisible(find.text('15'));
      await tester.tap(find.text('15'));
      await tester.pump();
      expect(find.byKey(const ValueKey('calendar-empty-state')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

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
      expect(
        tester
            .getSize(find.byKey(const ValueKey('calendar-month-card')))
            .height,
        greaterThan(600),
      );
      await tester.ensureVisible(find.text('27'));
      await tester.tap(find.text('27'));
      await tester.pump();
      expect(find.text('서버 일정'), findsOneWidget);
      expect(find.byType(ActionChip), findsNWidgets(5));
      await tester.ensureVisible(find.widgetWithText(ActionChip, '일정'));
      await tester.tap(find.widgetWithText(ActionChip, '일정'));
      await tester.pump();
      expect(find.text('서버 일정'), findsNothing);
      await tester.tap(find.widgetWithText(ActionChip, '전체'));
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
    testWidgets('Google 설정 연결 행 너비 $width', (tester) async {
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
      if (kIsWeb) {
        expect(find.text('Google Calendar 연결'), findsOneWidget);
      } else {
        expect(find.text('눌러서 연결'), findsOneWidget);
      }
      expect(find.text('테스트 일정 서버'), findsNothing);
      expect(find.text('앱 외부 알림'), findsNothing);
      expect(find.text('받을 알림 종류'), findsNothing);
      expect(find.text('테스트 서버 실시간 알림'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [390.0, 840.0]) {
    testWidgets('설정 서버 연결 버튼 너비 $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = CalendarSession()..setToken('app-session');
      final link = _ServerLink();
      final controller = CalendarController(
        appApi: _AppApi(),
        session: session,
        googleAuth: _Auth()
          ..account = const GoogleCalendarAccount('id', 'test@example.com'),
        googleApi: _GoogleApi(),
        serverLink: link,
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
      expect(find.text('Google 연결 계속'), findsOneWidget);
      await tester.tap(find.text('Google 연결 계속'));
      await tester.pumpAndSettle();
      expect(link.receivedCode, 'test-server-code');
      expect(controller.serverLinked, true);
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
