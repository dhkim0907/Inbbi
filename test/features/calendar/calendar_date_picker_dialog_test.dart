import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/features/calendar/calendar_date_picker_dialog.dart';

Future<void> openPicker(
  WidgetTester tester,
  DateTime initial,
  void Function(DateTime?) onResult,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              onResult(
                await showDialog<DateTime>(
                  context: context,
                  builder: (_) =>
                      CalendarDatePickerDialog(initialDate: initial),
                ),
              );
            },
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
  for (final width in [320.0, 390.0, 840.0, 1280.0]) {
    testWidgets('한글 세로형 날짜 선택과 연말 이동 너비 $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      DateTime? result;
      await openPicker(tester, DateTime(2026, 12, 31), (date) => result = date);
      expect(find.text('날짜 선택'), findsOneWidget);
      for (final weekday in ['월', '화', '수', '목', '금', '토', '일']) {
        expect(find.text(weekday), findsOneWidget);
      }
      expect(
        tester
            .getSize(find.byKey(const ValueKey('calendar-date-picker-content')))
            .width,
        lessThanOrEqualTo(360),
      );
      await tester.tap(find.byTooltip('다음 달'));
      await tester.pumpAndSettle();
      expect(find.text('2027년 1월'), findsOneWidget);
      await tester.tap(find.text('2'));
      await tester.pump();
      expect(result, isNull);
      expect(find.text('2027년 1월 2일 (토)'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(result, DateTime(2027, 1, 2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('연도와 월을 바꿔 윤년 날짜를 선택한다', (tester) async {
    DateTime? result;
    await openPicker(tester, DateTime(2023, 2, 1), (date) => result = date);
    await tester.tap(find.text('2023년 2월'));
    await tester.pump();
    await tester.tap(find.byTooltip('다음 연도'));
    await tester.pump();
    await tester.tap(find.text('2월'));
    await tester.pump();
    await tester.tap(find.text('29'));
    await tester.pump();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2024, 2, 29));
  });

  testWidgets('취소하면 고른 날짜를 반환하지 않는다', (tester) async {
    DateTime? result = DateTime(2026);
    await openPicker(tester, DateTime(2026, 10, 9), (date) => result = date);
    await tester.tap(find.text('15'));
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  for (final initial in [DateTime(2000), DateTime(2100, 12)]) {
    testWidgets('선택 범위를 벗어난 달 이동을 막는다 $initial', (tester) async {
      await openPicker(tester, initial, (_) {});
      final tooltip = initial.year == 2000 ? '이전 달' : '다음 달';
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == tooltip,
              ),
            )
            .onPressed,
        isNull,
      );
    });
  }
}
