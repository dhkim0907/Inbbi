import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/features/calendar/calendar_event_dialog.dart';
import 'package:inbbi/features/calendar/calendar_event_draft.dart';
import 'package:inbbi/features/calendar/google_calendar_api.dart';

Future<void> openDialog(
  WidgetTester tester,
  Future<void> Function(CalendarEventDraft) onSave,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<CalendarEventDraft>(
              context: context,
              barrierDismissible: false,
              builder: (_) => CalendarEventDialog(
                initialDate: DateTime(2026, 12, 31),
                onSave: onSave,
              ),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('작은 모바일 화면에서 키보드가 열려도 닫기와 저장을 표시한다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await openDialog(tester, (_) async {});
    await tester.enterText(
      find.byKey(const ValueKey('calendar-event-title')),
      '모바일 일정',
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('닫기').hitTestable(), findsOneWidget);
    expect(find.text('저장').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarEventDialog), findsNothing);
  });

  for (final width in [390.0, 840.0, 1280.0]) {
    testWidgets('종일 일정 저장과 연말 종료 날짜 너비 $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      CalendarEventDraft? saved;
      await openDialog(tester, (draft) async => saved = draft);
      await tester.enterText(
        find.byKey(const ValueKey('calendar-event-title')),
        '  연말 일정  ',
      );
      expect(find.text('일정'), findsOneWidget);
      expect(find.text('할일'), findsOneWidget);
      expect(find.text('시작 날짜'), findsOneWidget);
      expect(find.text('시작 시간'), findsOneWidget);
      final datePosition = tester.getTopLeft(find.text('시작 날짜'));
      final timePosition = tester.getTopLeft(find.text('시작 시간'));
      if (width >= 840) {
        expect(datePosition.dy, timePosition.dy);
      } else {
        expect(timePosition.dy, greaterThan(datePosition.dy));
      }
      final location = find.byKey(const ValueKey('calendar-event-location'));
      await tester.ensureVisible(location);
      await tester.enterText(location, '  도서관  ');
      final memo = find.byKey(const ValueKey('calendar-event-memo'));
      await tester.ensureVisible(memo);
      await tester.enterText(memo, '  준비물 챙기기  ');
      await tester.ensureVisible(find.byType(Checkbox).first);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(saved!.title, '연말 일정');
      expect(saved!.start, DateTime(2026, 12, 31));
      expect(saved!.end, DateTime(2027, 1, 1));
      expect(saved!.allDay, true);
      expect(saved!.category, '일정');
      expect(saved!.location, '도서관');
      expect(saved!.memo, '준비물 챙기기');
      expect(find.byType(CalendarEventDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('할일 탭을 선택해 저장하고 닫기로 취소한다', (tester) async {
    CalendarEventDraft? saved;
    await openDialog(tester, (draft) async => saved = draft);
    await tester.tap(find.text('할일'));
    await tester.pumpAndSettle();
    expect(find.text('어떤 할일이 있나요?'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('calendar-event-title')),
      '책 반납',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(saved!.category, '할일');
    await openDialog(tester, (_) async => fail('취소 시 저장하면 안 된다'));
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarEventDialog), findsNothing);
  });

  for (final width in [390.0, 840.0]) {
    testWidgets('메모 아래에서 앱 전용 저장을 선택한다 너비 $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      CalendarEventDraft? saved;
      await openDialog(tester, (draft) async => saved = draft);
      await tester.enterText(
        find.byKey(const ValueKey('calendar-event-title')),
        '개인 일정',
      );
      final option = find.byKey(const ValueKey('calendar-event-google-save'));
      final label = find.text('구글 캘린더에도 저장합니다.');
      expect(find.text('내 캘린더에만 저장'), findsNothing);
      expect(find.text('구글 캘린더에도 저장'), findsNothing);
      expect(tester.widget<Checkbox>(option).value, true);
      await tester.ensureVisible(option);
      expect(
        tester.getCenter(option).dx,
        lessThan(tester.getTopLeft(label).dx),
      );
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(option).value, false);
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(option).value, true);
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pump();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(saved!.saveTarget, CalendarSaveTarget.appOnly);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('빈 제목은 저장하지 않고 취소도 저장하지 않는다', (tester) async {
    var calls = 0;
    await openDialog(tester, (_) async => calls++);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('일정 제목을 입력해 주세요.'), findsOneWidget);
    expect(calls, 0);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(CalendarEventDialog), findsNothing);
  });

  testWidgets('시작보다 앞선 종료 날짜는 저장하지 않는다', (tester) async {
    var calls = 0;
    await openDialog(tester, (_) async => calls++);
    await tester.enterText(
      find.byKey(const ValueKey('calendar-event-title')),
      '날짜 검증',
    );
    final endDate = find.widgetWithText(OutlinedButton, '2026-12-31').last;
    await tester.ensureVisible(endDate);
    await tester.tap(endDate);
    await tester.pumpAndSettle();
    await tester.tap(find.text('30'));
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.ensureVisible(find.text('종료 날짜와 시간은 시작 이후로 설정해 주세요.'));
    expect(find.text('종료 날짜와 시간은 시작 이후로 설정해 주세요.'), findsOneWidget);
    expect(find.byType(CalendarEventDialog), findsOneWidget);
  });

  testWidgets('저장 중 중복 요청과 닫기를 막는다', (tester) async {
    var calls = 0;
    final pending = Completer<void>();
    CalendarEventDraft? saved;
    await openDialog(tester, (draft) {
      calls++;
      saved = draft;
      return pending.future;
    });
    await tester.enterText(
      find.byKey(const ValueKey('calendar-event-title')),
      '시간 일정',
    );
    await tester.tap(find.text('저장'));
    await tester.pump();
    expect(calls, 1);
    expect(saved!.start, DateTime(2026, 12, 31, 9));
    expect(saved!.end, DateTime(2026, 12, 31, 10));
    expect(saved!.allDay, false);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '취소'))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(CalendarEventDialog), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CalendarEventDialog), findsNothing);
    expect(calls, 1);
  });

  for (final error in [
    const GoogleCalendarAuthRequired(),
    StateError('offline'),
  ]) {
    testWidgets('저장 실패 시 입력을 유지하고 재시도한다 $error', (tester) async {
      var calls = 0;
      await openDialog(tester, (_) async {
        if (++calls == 1) throw error;
      });
      await tester.enterText(
        find.byKey(const ValueKey('calendar-event-title')),
        '보존할 일정',
      );
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(find.text('보존할 일정'), findsOneWidget);
      expect(
        find.textContaining(
          error is GoogleCalendarAuthRequired
              ? '설정에서 Google 캘린더를 연결'
              : '네트워크 연결을 확인',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(CalendarEventDialog), findsNothing);
    });
  }
}
