import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/features/calendar/calendar_event.dart';
import 'package:inbbi/features/calendar/calendar_event_presentation.dart';

void main() {
  final now = DateTime(2026, 10, 9, 12);
  CalendarEventPresentation present(
    String category, {
    DateTime? start,
    DateTime? end,
    bool completed = false,
    bool allDay = false,
    DateTime? at,
  }) => CalendarEventPresentation(
    event: CalendarEvent(
      id: 'test',
      source: CalendarSource.appServer,
      title: '테스트',
      category: category,
      start: start ?? DateTime(2026, 10, 9, 15),
      end: end ?? DateTime(2026, 10, 9, 16),
      allDay: allDay,
      isCompleted: completed,
    ),
    now: at ?? now,
  );

  test('오늘 마감은 시간을, 다른 날짜는 날짜와 시간을 표시한다', () {
    for (final category in ['강의', '과제', '할일']) {
      expect(present(category).timeLabel, '마감 16:00');
      expect(
        present(category, end: DateTime(2026, 10, 10, 0)).timeLabel,
        '마감 10/10 00:00',
      );
    }
  });

  test('일정은 시간 범위와 날짜 경계를 표시하고 완료 배지는 없다', () {
    expect(present('일정').timeLabel, '15:00~ 16:00');
    expect(present('일정').hasDeadline, isFalse);
    expect(
      present('일정', end: DateTime(2026, 10, 10, 1)).timeLabel,
      '15:00~ 10/10 01:00',
    );
    expect(present('일정', allDay: true).timeLabel, '종일');
  });

  test('마감 경계에서 미완료만 기한 지남으로 표시한다', () {
    expect(present('강의').statusLabel, '미완료');
    expect(
      present('강의', at: DateTime(2026, 10, 9, 16)).statusLabel,
      '미완료 · 기한 지남',
    );
    expect(
      present('과제', at: DateTime(2026, 10, 10), completed: true).statusLabel,
      '완료',
    );
    expect(present('일정', at: DateTime(2026, 10, 10)).isOverdue, isFalse);
  });

  test('종일 마감은 UTC 날짜를 현지 날짜로 사용하며 다음 날부터 초과한다', () {
    final before = present(
      '과제',
      allDay: true,
      start: DateTime.utc(2026, 10, 9),
      end: DateTime.utc(2026, 10, 10),
      at: DateTime(2026, 10, 9, 23, 59),
    );
    expect(before.timeLabel, '마감 23:59');
    expect(before.isOverdue, isFalse);
    expect(
      present(
        '과제',
        allDay: true,
        end: DateTime.utc(2026, 10, 10),
        at: DateTime(2026, 10, 10),
      ).isOverdue,
      isTrue,
    );
  });
}
