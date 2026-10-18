import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/features/calendar/app_calendar_api.dart';
import 'package:inbbi/features/calendar/calendar_controller.dart';
import 'package:inbbi/features/calendar/calendar_event.dart';
import 'package:inbbi/features/calendar/calendar_event_details_dialog.dart';
import 'package:inbbi/features/calendar/calendar_page.dart';
import 'package:inbbi/features/calendar/calendar_event_dialog.dart';
import 'package:inbbi/features/calendar/calendar_scope.dart';
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
  Future<String?> serverAuthorizationCode() async =>
      account == null ? null : 'test-server-code';
  @override
  Future<void> disconnect() async => account = null;
}

void main() {
  for (final width in [390.0, 840.0, 1280.0]) {
    testWidgets('일정 카드 선택으로 상세보기 열고 닫기 $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final today = DateTime.now();
      final event = CalendarEvent(
        id: 'test',
        source: CalendarSource.appServer,
        title: '프로젝트 보고서 정리',
        category: '할일',
        start: DateTime(today.year, today.month, today.day, 20),
        end: DateTime(today.year, today.month, today.day, 21),
        allDay: false,
      );
      final api = _AppApi()..events = [event];
      final controller = CalendarController(
        appApi: api,
        session: CalendarSession(),
        googleAuth: _Auth(),
        googleApi: _GoogleApi(),
      );
      addTearDown(controller.dispose);
      await controller.refreshApp();
      final notifications = NotificationService(_NotificationStorage());
      addTearDown(notifications.dispose);
      await tester.pumpWidget(
        NotificationScope(
          service: notifications,
          child: CalendarScope(
            controller: controller,
            child: const MaterialApp(home: CalendarPage()),
          ),
        ),
      );
      final title = find.text(event.title);
      await tester.ensureVisible(title);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarEventDetailsDialog), findsOneWidget);
      expect(find.text('상세 내용'), findsOneWidget);
      expect(find.text('21:00'), findsOneWidget);
      expect(find.text('메모 없음'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('상세보기 닫기'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarEventDetailsDialog), findsNothing);
    });
  }

  for (final width in [390.0, 840.0]) {
    testWidgets('샘플 수정·취소·삭제 확인과 목록 반영 $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final today = DateTime.now();
      final event = CalendarEvent(
        id: 'sample:actions',
        source: CalendarSource.appServer,
        title: '기존 할일',
        category: '할일',
        start: DateTime(today.year, today.month, today.day, 20),
        end: DateTime(today.year, today.month, today.day, 21),
        memo: '기존 메모',
        location: '도서관',
        allDay: false,
      );
      final controller = CalendarController(
        appApi: _AppApi(),
        session: CalendarSession(),
        googleAuth: _Auth(),
        googleApi: _GoogleApi(),
        sampleEvents: (_) => [event],
      );
      addTearDown(controller.dispose);
      final notifications = NotificationService(_NotificationStorage());
      addTearDown(notifications.dispose);
      await tester.pumpWidget(
        NotificationScope(
          service: notifications,
          child: CalendarScope(
            controller: controller,
            child: const MaterialApp(home: CalendarPage()),
          ),
        ),
      );
      await tester.ensureVisible(find.text('기존 할일'));
      await tester.tap(find.text('기존 할일'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('수정'));
      await tester.pumpAndSettle();
      final title = find.byKey(const ValueKey('calendar-event-title'));
      expect(tester.widget<TextFormField>(title).controller!.text, '기존 할일');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('calendar-event-memo')),
            )
            .controller!
            .text,
        '기존 메모',
      );
      await tester.enterText(title, '수정된 할일');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarEventDialog), findsNothing);
      expect(controller.events.single.title, '수정된 할일');
      expect(controller.events.single.location, '도서관');
      expect(controller.events.single.memo, '기존 메모');
      expect(find.text('수정된 할일'), findsNWidgets(2));
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(controller.events, hasLength(1));
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('삭제'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CalendarEventDetailsDialog), findsNothing);
      expect(controller.events, isEmpty);
      await controller.refresh();
      expect(controller.events, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('삭제 오류 시 상세 창 유지 및 재시도', (tester) async {
    final event = CalendarEvent(
      id: 'test',
      source: CalendarSource.appServer,
      title: '삭제 테스트',
      category: '일정',
      start: DateTime(2026, 10, 9, 15),
      end: DateTime(2026, 10, 9, 16),
      allDay: false,
    );
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('열기'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CalendarEventDetailsDialog(
                  event: event,
                  onDelete: (_) async {
                    calls++;
                    if (calls == 1) throw const CalendarAuthRequired();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('삭제'),
        ),
      );
      await tester.pumpAndSettle();
      if (attempt == 0) {
        expect(find.byType(CalendarEventDetailsDialog), findsOneWidget);
        expect(find.text('로그인이 만료되었어요. 다시 로그인해 주세요.'), findsOneWidget);
      }
    }
    expect(calls, 2);
    expect(find.byType(CalendarEventDetailsDialog), findsNothing);
  });

  testWidgets('종일 일정의 배타적 종료일과 긴 메모 표시', (tester) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final event = CalendarEvent(
      id: 'all-day',
      source: CalendarSource.appServer,
      title: '종일 과제',
      category: '과제',
      start: DateTime.utc(2026, 9, 1),
      end: DateTime.utc(2026, 9, 3),
      allDay: true,
      memo: '긴 메모 내용\n' * 50,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CalendarEventDetailsDialog(event: event),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('2026-09-02'), findsOneWidget);
    expect(find.text('종일'), findsOneWidget);
    expect(find.text('미완료 · 기한 지남'), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
