import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_http_client.dart';

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.expiresIn,
    this.refreshToken,
  });

  final String accessToken;
  final int expiresIn;
  final String? refreshToken;
}

class TestAuthApi {
  TestAuthApi(this.baseUrl, {http.Client? client})
    : _client = client ?? authHttpClient();

  final Uri baseUrl;
  final http.Client _client;

  Future<AuthTokens> login(String loginId, String password) async {
    final response = await _client
        .post(
          baseUrl.resolve('api/v1/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'loginId': loginId, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      throw const AuthException('아이디 또는 비밀번호를 확인해 주세요.');
    }
    return _parseTokens(response);
  }

  Future<AuthTokens> refresh(String? refreshToken) async {
    final response = await _client
        .post(
          baseUrl.resolve('api/v1/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(
            refreshToken == null
                ? <String, String>{}
                : {'refreshToken': refreshToken},
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      throw const AuthException('로그인 세션이 만료되었어요.');
    }
    return _parseTokens(response);
  }

  Future<void> logout(String? refreshToken) async {
    await _client
        .post(
          baseUrl.resolve('api/v1/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(
            refreshToken == null
                ? <String, String>{}
                : {'refreshToken': refreshToken},
          ),
        )
        .timeout(const Duration(seconds: 15));
  }

  AuthTokens _parseTokens(http.Response response) {
    if (response.statusCode != 200) {
      throw const AuthException('로그인 서버에 연결하지 못했어요.');
    }
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final access = data['accessToken'];
      final refresh = data['refreshToken'];
      final expiresIn = data['expiresIn'];
      if (access is! String ||
          access.isEmpty ||
          expiresIn is! int ||
          expiresIn <= 0 ||
          (refresh != null && (refresh is! String || refresh.isEmpty))) {
        throw const FormatException();
      }
      return AuthTokens(
        accessToken: access,
        expiresIn: expiresIn,
        refreshToken: refresh as String?,
      );
    } on FormatException {
      throw const AuthException('로그인 응답이 올바르지 않아요.');
    } on TypeError {
      throw const AuthException('로그인 응답이 올바르지 않아요.');
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}
