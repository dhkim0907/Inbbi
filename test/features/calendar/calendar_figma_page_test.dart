import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/core/theme/app_theme.dart';
import 'package:inbbi/features/calendar/app_calendar_api.dart';
import 'package:inbbi/features/calendar/calendar_controller.dart';
import 'package:inbbi/features/calendar/calendar_event.dart';
import 'package:inbbi/features/calendar/calendar_page.dart';
import 'package:inbbi/features/calendar/calendar_scope.dart';
import 'package:inbbi/features/calendar/google_calendar_api.dart';
import 'package:inbbi/features/calendar/google_calendar_auth.dart';
import 'package:inbbi/features/notification/notification_scope.dart';
import 'package:inbbi/features/notification/notification_service.dart';

import '../../support/ui_review.dart';

class _AppApi implements AppCalendarApi {
  @override
  Future<List<CalendarEvent>> fetchMonth(DateTime month) async => [
    CalendarEvent(
      id: 'period',
      source: CalendarSource.appServer,
      title: '팀 워크숍',
      location: '워크숍 장소',
      memo: '주를 넘기는 일정',
      category: '일정',
      start: DateTime.utc(2026, 9, 26),
      end: DateTime.utc(2026, 9, 30),
      allDay: true,
    ),
    CalendarEvent(
      id: 'multi-day-assignment',
      source: CalendarSource.appServer,
      title: '기간 과제',
      category: '과제',
      start: DateTime.utc(2026, 9, 30),
      end: DateTime.utc(2026, 10, 3),
      allDay: true,
    ),
    CalendarEvent(
      id: 'completed',
      source: CalendarSource.appServer,
      title: '완료한 과제',
      category: '과제',
      start: DateTime.utc(2026, 9, 30),
      end: DateTime.utc(2026, 10, 1),
      allDay: true,
      isCompleted: true,
    ),
    CalendarEvent(
      id: 'todo',
      source: CalendarSource.appServer,
      title: '팀플 자료 정리하기',
      category: '할일',
      start: DateTime(2026, 9, 30, 18),
      end: DateTime(2026, 9, 30, 19),
      allDay: false,
    ),
  ];
}

class _Auth implements GoogleCalendarAuth {
  @override
  bool get configured => false;
  @override
  bool get needsWebButton => false;
  @override
  Stream<GoogleCalendarAccount?> get changes => const Stream.empty();
  @override
  Future<GoogleCalendarAccount?> restore() async => null;
  @override
  Future<GoogleCalendarAccount?> connect() async => null;
  @override
  Future<String?> accessToken({bool interactive = false}) async => null;
  @override
  Future<String?> serverAuthorizationCode() async => null;
  @override
  Future<void> disconnect() async {}
}

class _GoogleApi implements GoogleCalendarApi {
  @override
  Future<GoogleCalendarFetchResult> fetchMonth(
    DateTime month,
    String token,
  ) async => GoogleCalendarFetchResult([], 0);
}

class _Storage implements NotificationStorage {
  @override
  Future<String?> load() async => null;
  @override
  Future<void> save(String value) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadReviewFonts);
  for (final width in [390.0, 839.0, 840.0, 1207.0]) {
    testWidgets('Figma 캘린더의 기간·필터·이전/다음 월과 선택 날짜 너비 $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
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
      await controller.setMonth(DateTime(2026, 9));
      final notifications = NotificationService(_Storage());
      addTearDown(notifications.dispose);
      await notifications.initialize();
      final boundary = GlobalKey();
      final review = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: review,
          child: NotificationScope(
            service: notifications,
            child: CalendarScope(
              controller: controller,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                home: RepaintBoundary(
                  key: boundary,
                  child: CalendarPage(
                    initialDate: DateTime(2026, 9, width < 840 ? 29 : 12),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if ([390.0, 1207.0].contains(width)) {
        await captureReview(tester, boundary, 'calendar-${width.toInt()}');
      }
      final day29 = find.byKey(const ValueKey('calendar-day:2026-9-29'));
      await tester.ensureVisible(day29);
      await tester.tap(day29);
      await tester.pump();
      expect(find.text('팀 워크숍'), findsOneWidget);
      expect(find.text('팀플 자료 정리하기'), findsOneWidget);
      expect(
        find.text('하루 종일 · 워크숍 장소 · 2026-09-26 ~ 2026-09-29'),
        findsOneWidget,
      );
      expect(find.text('주를 넘기는 일정'), findsOneWidget);
      expect(find.text('기간 과제'), findsOneWidget);
      expect(find.text('10월 2일 금요일'), findsOneWidget);
      expect(find.text('완료한 과제'), findsNothing);
      expect(find.text('마감 23:59'), findsOneWidget);
      await tester.ensureVisible(find.text('팀 워크숍'));
      await captureReview(tester, review, 'calendar-agenda-${width.toInt()}');
      await tester.tap(find.text('팀 워크숍'));
      await tester.pumpAndSettle();
      await captureReview(tester, review, 'calendar-details-${width.toInt()}');
      await tester.tap(find.byTooltip('상세보기 닫기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await captureReview(tester, review, 'calendar-add-menu-${width.toInt()}');
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('calendar-add-일정')), findsNothing);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('추가 메뉴 닫기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('calendar-add-일정')), findsNothing);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('calendar-add-일정')));
      await tester.pumpAndSettle();
      expect(find.text('일정 추가'), findsOneWidget);
      await captureReview(tester, review, 'calendar-schedule-${width.toInt()}');
      await tester.tap(find.widgetWithText(TextButton, '할일'));
      await tester.pumpAndSettle();
      await captureReview(tester, review, 'calendar-todo-${width.toInt()}');
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('calendar-add-할일')));
      await tester.pumpAndSettle();
      expect(find.text('할일 추가'), findsOneWidget);
      expect(find.text('마감 날짜'), findsOneWidget);
      expect(find.text('시작 날짜'), findsNothing);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      final filter = find.byKey(const ValueKey('calendar-filter-할일-false'));
      await tester.ensureVisible(filter);
      await tester.tap(filter);
      await tester.pump();
      expect(find.text('팀 워크숍'), findsNothing);
      expect(find.text('표시할 할일이 없어요.'), findsOneWidget);
      expect(find.text('팀플 자료 정리하기'), findsNothing);
      expect(find.text('미완료 강의·과제·할일'), findsNothing);
      await tester.tap(find.byTooltip('다음 달'));
      await tester.pumpAndSettle();
      expect(controller.month, DateTime(2026, 10));
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();
      expect(controller.month, DateTime(2026, 9));
      final previous = find.byKey(const ValueKey('calendar-day:2026-8-31'));
      await tester.tap(previous);
      await tester.pumpAndSettle();
      expect(controller.month, DateTime(2026, 8));
      expect(find.text('8월 31일 월요일'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('날짜 선택'));
      await tester.tap(find.byTooltip('날짜 선택'));
      await tester.pumpAndSettle();
      await captureReview(
        tester,
        review,
        'calendar-date-jump-${width.toInt()}',
      );
      await tester.enterText(find.byType(TextFormField), '2027-02-29');
      await tester.tap(find.text('이동'));
      await tester.pump();
      expect(find.text('2000~2100년의 올바른 날짜를 입력해 주세요.'), findsOneWidget);
      expect(controller.month, DateTime(2026, 8));
      await tester.enterText(find.byType(TextFormField), '2028-02-29');
      await tester.tap(find.text('이동'));
      await tester.pumpAndSettle();
      expect(controller.month, DateTime(2028, 2));
      expect(find.text('2월 29일 화요일'), findsOneWidget);
      await tester.tap(find.byTooltip('날짜 선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('오늘'));
      await tester.pump();
      await tester.tap(find.text('이동'));
      await tester.pumpAndSettle();
      final today = DateTime.now();
      expect(controller.month, DateTime(today.year, today.month));
      await tester.tap(find.byTooltip('날짜 선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('달력에서 날짜 선택'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('calendar-date-picker-content')),
        findsOneWidget,
      );
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.text('이동'), findsNothing);
      expect(controller.month, DateTime(today.year, today.month));
      expect(tester.takeException(), isNull);
    });
  }
}
