import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inbbi/features/calendar/calendar_event_draft.dart';
import 'package:inbbi/features/calendar/calendar_event_writer.dart';
import 'package:inbbi/features/calendar/app_calendar_api.dart';
import 'package:inbbi/features/calendar/google_calendar_api.dart';

void main() {
  test('수정 시 빈 장소와 메모도 전달해 기존 내용을 지울 수 있다', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response.bytes(
        utf8.encode(jsonEncode({'id': 'id', ...body})),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final draft = CalendarEventDraft(
      title: '제목',
      start: DateTime.utc(2026, 10, 9, 15),
      end: DateTime.utc(2026, 10, 9, 16),
      allDay: false,
    );
    await HttpGoogleCalendarEventWriter(
      client: client,
    ).update('google:primary:id', draft, 'test-token');
    await HttpAppCalendarEventWriter(
      baseUrl: Uri.parse('https://api.example.com/'),
      client: client,
      appOnly: true,
    ).update('server:id', draft, 'test-token');
    for (final request in requests) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['location'], '');
      expect(body['description'], '');
    }
  });

  for (final appOnly in [true, false]) {
    test('서버 삭제 경로와 빈 응답 처리 appOnly=$appOnly', () async {
      final requests = <http.Request>[];
      final writer = HttpAppCalendarEventWriter(
        baseUrl: Uri.parse('https://api.example.com/'),
        appOnly: appOnly,
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('', 204);
        }),
      );
      await writer.delete('server:delete1', 'test-token');
      expect(requests.single.method, 'DELETE');
      expect(
        requests.single.url.path,
        '/api/v1/calendar/${appOnly ? 'app-events' : 'events'}/delete1',
      );
      expect(requests.single.body, isEmpty);
      expect(requests.single.headers['Authorization'], 'Bearer test-token');
      await expectLater(
        writer.delete('google:primary:delete1', 'test-token'),
        throwsArgumentError,
      );
      expect(requests, hasLength(1));
    });
  }

  test('Google 삭제는 기본 캘린더의 원래 ID로 빈 본문 요청', () async {
    final requests = <http.Request>[];
    final writer = HttpGoogleCalendarEventWriter(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      }),
    );
    await writer.delete('google:primary:delete1', 'test-token');
    expect(requests.single.method, 'DELETE');
    expect(
      requests.single.url.path,
      '/calendar/v3/calendars/primary/events/delete1',
    );
    expect(requests.single.body, isEmpty);
  });

  for (final status in [401, 403, 404, 500]) {
    test('삭제 HTTP 오류를 분류한다 $status', () async {
      final client = MockClient((_) async => http.Response('', status));
      final server = HttpAppCalendarEventWriter(
        baseUrl: Uri.parse('https://api.example.com/'),
        client: client,
      );
      final google = HttpGoogleCalendarEventWriter(client: client);
      await expectLater(
        server.delete('server:id', 'test-token'),
        status == 401 || status == 403
            ? throwsA(isA<CalendarAuthRequired>())
            : status == 404
            ? throwsA(isA<CalendarEventNotFound>())
            : throwsStateError,
      );
      await expectLater(
        google.delete('google:primary:id', 'test-token'),
        switch (status) {
          401 => throwsA(isA<GoogleCalendarAuthRequired>()),
          403 => throwsA(isA<GoogleCalendarAccessDenied>()),
          404 => throwsA(isA<CalendarEventNotFound>()),
          _ => throwsStateError,
        },
      );
    });
  }

  test('앱 전용 API에 Google 대상 정보 없이 저장한다', () async {
    final requests = <http.Request>[];
    final writer = HttpAppCalendarEventWriter(
      baseUrl: Uri.parse('https://api.example.com/'),
      appOnly: true,
      client: MockClient((request) async {
        requests.add(request);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response.bytes(
          utf8.encode(jsonEncode({'id': 'app1', ...body})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final draft = CalendarEventDraft(
      title: '개인 일정',
      category: '일정',
      start: DateTime.utc(2026, 10, 9, 9),
      end: DateTime.utc(2026, 10, 9, 10),
      allDay: false,
      saveTarget: CalendarSaveTarget.appOnly,
    );
    final event = await writer.create(draft, 'test-token');
    expect(event.title, '개인 일정');
    expect(requests.single.url.path, '/api/v1/calendar/app-events');
    expect(requests.single.headers['Authorization'], 'Bearer test-token');
    expect(jsonDecode(requests.single.body), isNot(contains('calendarId')));
  });

  for (final category in ['일정', '할일']) {
    test('$category 장소와 메모를 전송하고 조회 결과에서 복원한다', () {
      final draft = CalendarEventDraft(
        title: '입력 테스트',
        start: DateTime.utc(2026, 10, 2, 9),
        end: DateTime.utc(2026, 10, 2, 10),
        allDay: false,
        category: category,
        location: ' 도서관 ',
        memo: ' 준비물 챙기기 ',
      );
      final googleJson = draft.toGoogleJson();
      expect(googleJson['location'], '도서관');
      expect(googleJson['description'], '준비물 챙기기');
      expect(googleJson['extendedProperties'], {
        'private': {'inbbiCategory': category},
      });
      final googleEvent = parseGoogleEvent({'id': 'g1', ...googleJson})!;
      final serverJson = draft.toServerJson();
      expect(serverJson['category'], category);
      expect(serverJson['location'], '도서관');
      expect(serverJson['description'], '준비물 챙기기');
      final serverEvent = parseAppCalendarEvent({'id': 's1', ...serverJson});
      for (final event in [googleEvent, serverEvent]) {
        expect(event.category, category);
        expect(event.location, '도서관');
        expect(event.memo, '준비물 챙기기');
      }
    });
  }

  test('종일 일정의 종료일은 배타적 날짜로 전송한다', () {
    final draft = CalendarEventDraft(
      title: ' 휴일 ',
      start: DateTime.utc(2026, 9, 27),
      end: DateTime.utc(2026, 9, 29),
      allDay: true,
    );
    expect(draft.toGoogleJson(), {
      'summary': '휴일',
      'start': {'date': '2026-09-27'},
      'end': {'date': '2026-09-29'},
    });
    expect(draft.toServerJson()['end'], '2026-09-29');
    expect(
      () => CalendarEventDraft(
        title: '잘못된 일정',
        start: DateTime(2026, 9, 27),
        end: DateTime(2026, 9, 27),
        allDay: false,
      ),
      throwsArgumentError,
    );
  });

  test('Google 기본 캘린더에 생성하고 기존 일정만 수정한다', () async {
    final requests = <http.Request>[];
    final writer = HttpGoogleCalendarEventWriter(
      client: MockClient((request) async {
        requests.add(request);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'id': 'g1',
              'summary': body['summary'],
              'start': body['start'],
              'end': body['end'],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final draft = CalendarEventDraft(
      title: '시험',
      start: DateTime.utc(2026, 9, 27, 9),
      end: DateTime.utc(2026, 9, 27, 10),
      allDay: false,
    );
    final created = await writer.create(draft, 'google-token');
    final updated = await writer.update(created.id, draft, 'google-token');
    expect(created.id, 'google:primary:g1');
    expect(updated.title, '시험');
    expect(requests.map((r) => r.method), ['POST', 'PATCH']);
    expect(requests.first.url.path, '/calendar/v3/calendars/primary/events');
    expect(requests.last.url.path, '/calendar/v3/calendars/primary/events/g1');
    expect(
      requests.every(
        (r) => r.headers['Authorization'] == 'Bearer google-token',
      ),
      true,
    );
    expect((jsonDecode(requests.first.body) as Map)['start'], {
      'dateTime': '2026-09-27T09:00:00.000Z',
    });
    await expectLater(
      writer.update('server:g1', draft, 'google-token'),
      throwsArgumentError,
    );
    expect(requests.length, 2);
  });

  test('서버 연결 쓰기는 앱 인증과 Google 대상 정보를 전송한다', () async {
    final requests = <http.Request>[];
    final writer = HttpAppCalendarEventWriter(
      baseUrl: Uri.parse('https://api.example.com/'),
      client: MockClient((request) async {
        requests.add(request);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response.bytes(
          utf8.encode(jsonEncode({'id': 's1', ...body})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final draft = CalendarEventDraft(
      title: '시험',
      start: DateTime.utc(2026, 9, 27, 9),
      end: DateTime.utc(2026, 9, 27, 10),
      allDay: false,
    );
    final created = await writer.create(draft, 'app-token');
    await writer.update(created.id, draft, 'app-token');
    expect(requests.map((r) => r.method), ['POST', 'PATCH']);
    expect(requests.last.url.path, '/api/v1/calendar/events/s1');
    expect(
      requests.every((r) => r.headers['Authorization'] == 'Bearer app-token'),
      true,
    );
    expect((jsonDecode(requests.first.body) as Map)['calendarId'], 'primary');
  });
}
