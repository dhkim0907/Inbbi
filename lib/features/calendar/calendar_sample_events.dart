import 'calendar_event.dart';

/// 화면 확인용 데이터. 서버나 Google 캘린더에 저장하지 않는다.
List<CalendarEvent> calendarSampleEvents(
  DateTime month, {
  DateTime? referenceDate,
}) {
  final today = referenceDate ?? DateTime.now();
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  final day = today.day.clamp(1, lastDay);
  final prefix = 'sample:${month.year}-${month.month}';
  const titles = {
    '강의': ['자료구조 강의', '알고리즘 복습 강의'],
    '과제': ['프로그래밍 과제 제출', '데이터베이스 보고서 제출'],
    '일정': ['팀 프로젝트 회의', '지도 교수 상담'],
    '할일': ['발표 자료 준비', '도서관 책 반납'],
  };
  final events = <CalendarEvent>[];
  var hour = 9;
  for (final entry in titles.entries) {
    for (var index = 0; index < entry.value.length; index++) {
      events.add(
        CalendarEvent(
          id: '$prefix:${entry.key}:$index',
          source: CalendarSource.appServer,
          title: '[샘플] ${entry.value[index]}',
          category: entry.key,
          start: DateTime(month.year, month.month, day, hour),
          end: DateTime(month.year, month.month, day, hour + 1),
          allDay: false,
          isCompleted: index == 1,
          location: entry.key == '강의' ? '공학관 301호' : '',
          memo: '캘린더 표시 확인용 샘플 데이터입니다.',
        ),
      );
      hour++;
    }
  }
  events.addAll([
    CalendarEvent(
      id: '$prefix:all-day',
      source: CalendarSource.appServer,
      title: '[샘플] 과제 제출 마감 (종일)',
      category: '과제',
      start: DateTime.utc(month.year, month.month, day),
      end: DateTime.utc(month.year, month.month, day + 1),
      allDay: true,
    ),
    CalendarEvent(
      id: '$prefix:multi-day',
      source: CalendarSource.appServer,
      title: '[샘플] 프로젝트 집중 작업 (여러 날)',
      category: '일정',
      start: DateTime.utc(month.year, month.month, lastDay - 1),
      end: DateTime.utc(month.year, month.month + 1, 2),
      allDay: true,
    ),
  ]);
  return events;
}
