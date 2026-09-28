import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inbbi/features/calendar/calendar_event_draft.dart';
import 'package:inbbi/features/calendar/calendar_event_writer.dart';

void main() {
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
