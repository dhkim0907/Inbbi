import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/features/calendar/calendar_sample_events.dart';

void main() {
  test('각 종류의 완료·미완료 샘플이 기준 날짜에 표시된다', () {
    final date = DateTime(2026, 10, 9);
    final events = calendarSampleEvents(date, referenceDate: date);
    for (final category in ['강의', '과제', '일정', '할일']) {
      final timed = events.where(
        (event) => event.category == category && !event.allDay,
      );
      expect(timed.map((event) => event.isCompleted).toSet(), {false, true});
      expect(timed.every((event) => event.occursOn(date)), isTrue);
    }
    expect(events.map((event) => event.id).toSet().length, events.length);
    expect(events.every((event) => event.title.startsWith('[샘플]')), isTrue);
  });

  test('짧은 달에서도 유효한 날짜와 배타적 종일 종료일을 사용한다', () {
    final events = calendarSampleEvents(
      DateTime(2027, 2),
      referenceDate: DateTime(2026, 10, 31),
    );
    final allDay = events.singleWhere((event) => event.id.endsWith(':all-day'));
    expect(allDay.start, DateTime.utc(2027, 2, 28));
    expect(allDay.occursOn(DateTime(2027, 2, 28)), isTrue);
    expect(allDay.occursOn(DateTime(2027, 3, 1)), isFalse);
    final multiDay = events.singleWhere(
      (event) => event.id.endsWith(':multi-day'),
    );
    expect(multiDay.occursOn(DateTime(2027, 2, 27)), isTrue);
    expect(multiDay.occursOn(DateTime(2027, 3, 1)), isTrue);
    expect(multiDay.occursOn(DateTime(2027, 3, 2)), isFalse);
    expect(
      events.every((event) => event.overlapsMonth(DateTime(2027, 2))),
      isTrue,
    );
  });
}
