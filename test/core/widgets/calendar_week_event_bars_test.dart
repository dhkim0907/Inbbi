import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/core/widgets/calendar_week_event_bars.dart';
import 'package:inbbi/core/widgets/month_calendar_grid.dart';
import 'package:inbbi/features/calendar/calendar_event.dart';

CalendarEvent event(
  String id,
  DateTime start,
  DateTime end, {
  bool allDay = true,
}) => CalendarEvent(
  id: id,
  source: CalendarSource.appServer,
  title: id,
  category: '일정',
  start: start,
  end: end,
  allDay: allDay,
);

void main() {
  testWidgets('기간이 세 개 겹치면 두 막대와 숨은 일정 개수를 날짜별로 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 350,
            child: CalendarWeekEventBars(
              dates: [
                for (var day = 21; day <= 27; day++) DateTime(2026, 9, day),
              ],
              events: [
                event(
                  'a',
                  DateTime.utc(2026, 9, 21),
                  DateTime.utc(2026, 9, 25),
                ),
                event(
                  'b',
                  DateTime.utc(2026, 9, 22),
                  DateTime.utc(2026, 9, 26),
                ),
                event(
                  'c',
                  DateTime.utc(2026, 9, 23),
                  DateTime.utc(2026, 9, 27),
                ),
              ],
              maxVisibleLanes: 2,
              minimumHeight: 93,
              laneHeight: 11,
              barHeight: 6,
            ),
          ),
        ),
      ),
    );
    final bars = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('calendar-bar:'),
    );
    expect(bars, findsNWidgets(2));
    expect(find.text('+1'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('겹치는 기간은 별도 선에 배치하고 단일 날짜는 선에서 제외한다', (tester) async {
    final events = [
      event('first', DateTime.utc(2026, 9, 21), DateTime.utc(2026, 9, 25)),
      event('overlap', DateTime.utc(2026, 9, 22), DateTime.utc(2026, 9, 26)),
      event('separate', DateTime.utc(2026, 9, 26), DateTime.utc(2026, 9, 28)),
      event('all-day', DateTime.utc(2026, 9, 21), DateTime.utc(2026, 9, 22)),
      event(
        'midnight',
        DateTime(2026, 9, 21, 23),
        DateTime(2026, 9, 22),
        allDay: false,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 350,
            child: CalendarWeekEventBars(
              dates: [
                for (var day = 21; day <= 27; day++) DateTime(2026, 9, day),
              ],
              events: events,
            ),
          ),
        ),
      ),
    );
    Finder bar(String id, int day) => find.byKey(
      ValueKey('calendar-bar:$id:${DateTime(2026, 9, day).toIso8601String()}'),
    );
    expect(tester.getSize(bar('first', 21)).width, 194);
    expect(tester.getSize(bar('overlap', 22)).width, 194);
    expect(
      tester.getTopLeft(bar('first', 21)).dy,
      tester.getTopLeft(bar('separate', 26)).dy,
    );
    expect(
      tester.getTopLeft(bar('overlap', 22)).dy,
      tester.getTopLeft(bar('first', 21)).dy + 8,
    );
    expect(bar('all-day', 21), findsNothing);
    expect(bar('midnight', 21), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 840.0, 1280.0]) {
    testWidgets('주·월 경계에서 선을 나누고 날짜 선택 유지 너비 $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthCalendarGrid(
              month: DateTime(2026, 9),
              eventDays: const {},
              showNextMonthDays: true,
              events: [
                event(
                  'boundary',
                  DateTime.utc(2026, 9, 26),
                  DateTime.utc(2026, 10, 3),
                ),
                event(
                  'timed',
                  DateTime(2026, 9, 30, 23),
                  DateTime(2026, 10, 1, 1),
                  allDay: false,
                ),
              ],
              onDaySelected: (day) => selected = day,
            ),
          ),
        ),
      );
      Finder bar(String id, DateTime date) =>
          find.byKey(ValueKey('calendar-bar:$id:${date.toIso8601String()}'));
      expect(bar('boundary', DateTime(2026, 9, 26)), findsOneWidget);
      expect(bar('boundary', DateTime(2026, 9, 28)), findsOneWidget);
      expect(bar('timed', DateTime(2026, 9, 30)), findsOneWidget);
      final week = find
          .ancestor(
            of: find.ancestor(
              of: bar('boundary', DateTime(2026, 9, 28)),
              matching: find.byType(CalendarWeekEventBars),
            ),
            matching: find.byType(Stack),
          )
          .last;
      final lineCenter =
          (tester.getCenter(bar('boundary', DateTime(2026, 9, 28))).dy +
              tester.getCenter(bar('timed', DateTime(2026, 9, 30))).dy) /
          2;
      expect(lineCenter, closeTo(tester.getCenter(week).dy - 2, 0.01));
      expect(
        tester.getTopLeft(bar('boundary', DateTime(2026, 9, 28))).dy,
        greaterThan(tester.getBottomLeft(find.text('30')).dy),
      );
      final column = width / 7;
      expect(
        tester.getSize(bar('boundary', DateTime(2026, 9, 26))).width,
        closeTo(column * 2 - 6, 0.01),
      );
      expect(
        tester.getSize(bar('boundary', DateTime(2026, 9, 28))).width,
        closeTo(column * 5 - 6, 0.01),
      );
      await tester.tap(find.text('30'));
      expect(selected, 30);
      expect(tester.takeException(), isNull);
    });
  }
}
