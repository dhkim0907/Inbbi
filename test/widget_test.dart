import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/core/widgets/month_calendar_grid.dart';

void main() {
  testWidgets('월간 그리드에서 날짜 선택을 전달한다', (tester) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthCalendarGrid(
            month: DateTime(2026, 9),
            eventDays: const {15},
            selectedDay: 15,
            onDaySelected: (day) => selected = day,
          ),
        ),
      ),
    );
    await tester.tap(find.text('16'));
    expect(selected, 16);
  });
}
