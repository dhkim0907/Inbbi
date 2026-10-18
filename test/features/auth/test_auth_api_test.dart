import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inbbi/features/auth/test_auth_api.dart';
import 'package:inbbi/features/auth/auth_session_service.dart';
import 'package:inbbi/features/auth/refresh_token_store.dart';
import 'package:inbbi/core/app_routes.dart';
import 'package:inbbi/features/auth/auth_scope.dart';
import 'package:inbbi/features/auth/login_page.dart';
import 'package:inbbi/features/calendar/app_calendar_api.dart';
import 'package:inbbi/features/calendar/calendar_controller.dart';
import 'package:inbbi/features/calendar/calendar_scope.dart';
import 'package:inbbi/features/calendar/google_calendar_api.dart';
import 'package:inbbi/features/calendar/google_calendar_auth.dart';

class MemoryRefreshTokenStore implements RefreshTokenStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async => token = value;
  @override
  Future<void> clear() async => token = null;
}

void main() {
  for (final width in [390.0, 840.0]) {
    testWidgets('서버 미설정 로그인은 너비 $width 에서 홈으로 이동한다', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = CalendarSession();
      final googleAuth = GoogleSignInCalendarAuth();
      final calendar = CalendarController(
        appApi: HttpAppCalendarApi(baseUrl: null, session: session),
        session: session,
        googleAuth: googleAuth,
        googleApi: HttpGoogleCalendarApi(),
      );
      addTearDown(calendar.dispose);
      addTearDown(googleAuth.dispose);
      await tester.pumpWidget(
        AuthScope(
          service: AuthSessionService(
            baseUrl: null,
            store: MemoryRefreshTokenStore(),
          ),
          child: CalendarScope(
            controller: calendar,
            child: MaterialApp(
              home: const LoginPage(),
              routes: {
                AppRoutes.home: (_) => const Scaffold(body: Text('홈 진입 완료')),
              },
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pumpAndSettle();
      expect(find.text('홈 진입 완료'), findsOneWidget);
      expect(session.token, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  test('서버 미설정 시 토큰 없이 로그인하고 갱신 요청을 하지 않는다', () async {
    final store = MemoryRefreshTokenStore();
    final session = AuthSessionService(baseUrl: null, store: store);

    expect(await session.login('', ''), isNull);
    expect(session.accessToken, isNull);
    expect(store.token, isNull);
    expect(await session.refreshIfNeeded(), isNull);
    await session.logout();
    expect(store.token, isNull);
  });

  test('성공 시 앱 토큰을 반환하고 테스트 계정을 전송한다', () async {
    final api = TestAuthApi(
      Uri.parse('https://example.test/'),
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/login');
        expect(jsonDecode(request.body), {
          'loginId': 'test-a',
          'password': 'secret',
        });
        return http.Response(
          jsonEncode({
            'accessToken': 'app-token',
            'refreshToken': 'refresh-1',
            'expiresIn': 3600,
          }),
          200,
        );
      }),
    );
    final tokens = await api.login('test-a', 'secret');
    expect(tokens.accessToken, 'app-token');
    expect(tokens.refreshToken, 'refresh-1');
  });

  test('잘못된 비밀번호는 로그인 실패로 처리한다', () async {
    final api = TestAuthApi(
      Uri.parse('https://example.test/'),
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    await expectLater(
      api.login('test-a', 'wrong'),
      throwsA(isA<AuthException>()),
    );
  });

  test('앱 재시작 시 저장된 복원 토큰을 교체하고 새 앱 토큰을 사용한다', () async {
    final store = MemoryRefreshTokenStore();
    final api = TestAuthApi(
      Uri.parse('https://example.test/'),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(
            jsonEncode({
              'accessToken': 'access-1',
              'refreshToken': 'refresh-1',
              'expiresIn': 3600,
            }),
            200,
          );
        }
        expect(request.url.path, '/api/v1/auth/refresh');
        expect(jsonDecode(request.body), {'refreshToken': 'refresh-1'});
        return http.Response(
          jsonEncode({
            'accessToken': 'access-2',
            'refreshToken': 'refresh-2',
            'expiresIn': 3600,
          }),
          200,
        );
      }),
    );
    final first = AuthSessionService(baseUrl: null, api: api, store: store);
    expect(await first.login('test-a', 'secret'), 'access-1');
    expect(store.token, 'refresh-1');
    final restarted = AuthSessionService(baseUrl: null, api: api, store: store);
    expect(await restarted.restore(), 'access-2');
    expect(store.token, 'refresh-2');
  });

  test('만료된 복원 토큰을 삭제한다', () async {
    final store = MemoryRefreshTokenStore()..token = 'expired';
    final api = TestAuthApi(
      Uri.parse('https://example.test/'),
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    final session = AuthSessionService(baseUrl: null, api: api, store: store);
    expect(await session.restore(), isNull);
    expect(store.token, isNull);
  });

  test('동시 복원 요청은 복원 토큰을 한 번만 사용한다', () async {
    final store = MemoryRefreshTokenStore()..token = 'refresh-1';
    var requests = 0;
    final api = TestAuthApi(
      Uri.parse('https://example.test/'),
      client: MockClient((_) async {
        requests++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return http.Response(
          jsonEncode({
            'accessToken': 'access-2',
            'refreshToken': 'refresh-2',
            'expiresIn': 3600,
          }),
          200,
        );
      }),
    );
    final session = AuthSessionService(baseUrl: null, api: api, store: store);
    expect(await Future.wait([session.restore(), session.restore()]), [
      'access-2',
      'access-2',
    ]);
    expect(requests, 1);
    expect(store.token, 'refresh-2');
  });

  test('로그아웃은 서버에 복원 토큰을 보내고 로컬 저장소를 비운다', () async {
    final store = MemoryRefreshTokenStore()..token = 'refresh-1';
    final api = TestAuthApi(
      Uri.parse('https://example.test/'),
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/logout');
        expect(jsonDecode(request.body), {'refreshToken': 'refresh-1'});
        return http.Response('{"ok":true}', 200);
      }),
    );
    final session = AuthSessionService(baseUrl: null, api: api, store: store);
    await session.logout();
    expect(store.token, isNull);
  });
}
