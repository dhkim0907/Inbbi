import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inbbi/features/calendar/app_calendar_api.dart';
import 'package:inbbi/features/calendar/google_calendar_server_link.dart';

void main() {
  test('일회용 인증 코드를 인증된 서버로만 전송한다', () async {
    final requests = <http.Request>[];
    final link = HttpGoogleCalendarServerLink(
      baseUrl: Uri.parse('https://api.example.com/'),
      session: CalendarSession()..setToken('app-session'),
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      }),
    );

    await link.connect('one-time-code');
    await link.disconnect();

    expect(requests.map((request) => request.method), ['POST', 'DELETE']);
    expect(
      requests.every(
        (request) =>
            request.url.toString() ==
                'https://api.example.com/api/v1/calendar/google/connection' &&
            request.headers['Authorization'] == 'Bearer app-session',
      ),
      true,
    );
    expect(jsonDecode(requests.first.body), {
      'authorizationCode': 'one-time-code',
    });
    expect(requests.last.body, isEmpty);
  });

  test('앱 로그인 토큰 없이는 Google 코드를 전송하지 않는다', () async {
    var called = false;
    final link = HttpGoogleCalendarServerLink(
      baseUrl: Uri.parse('https://api.example.com/'),
      session: CalendarSession(),
      client: MockClient((_) async {
        called = true;
        return http.Response('', 204);
      }),
    );
    await expectLater(
      link.connect('one-time-code'),
      throwsA(isA<GoogleServerLinkAuthRequired>()),
    );
    expect(called, false);
  });

  test('서버의 인증 거부를 별도 오류로 처리한다', () async {
    final link = HttpGoogleCalendarServerLink(
      baseUrl: Uri.parse('https://api.example.com/'),
      session: CalendarSession()..setToken('expired'),
      client: MockClient((_) async => http.Response('', 401)),
    );
    await expectLater(
      link.connect('one-time-code'),
      throwsA(isA<GoogleServerLinkAuthRequired>()),
    );
  });

  test('앱 사용자별 서버 연결 상태를 조회한다', () async {
    final link = HttpGoogleCalendarServerLink(
      baseUrl: Uri.parse('https://api.example.com/'),
      session: CalendarSession()..setToken('app-session'),
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer app-session');
        return http.Response('{"connected":true}', 200);
      }),
    );
    expect(await link.isConnected(), true);
  });
}
