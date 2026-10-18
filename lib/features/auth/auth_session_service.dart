import 'package:flutter/foundation.dart';

import 'refresh_token_store.dart';
import 'test_auth_api.dart';

class AuthSessionService {
  AuthSessionService({
    required Uri? baseUrl,
    TestAuthApi? api,
    RefreshTokenStore? store,
  }) : _api = api ?? (baseUrl == null ? null : TestAuthApi(baseUrl)),
       _store = store ?? createRefreshTokenStore();

  final TestAuthApi? _api;
  final RefreshTokenStore _store;
  String? accessToken;
  DateTime? _expiresAt;
  Future<String?>? _refreshing;

  Future<String?> login(String loginId, String password) async {
    final api = _api;
    if (api == null) {
      // 서버 미설정 시에는 서버 인증 없이 앱에 진입한다.
      return null;
    }
    final tokens = await api.login(loginId, password);
    if (tokens.refreshToken != null) {
      await _store.write(tokens.refreshToken!);
    }
    accessToken = tokens.accessToken;
    _expiresAt = DateTime.now().add(Duration(seconds: tokens.expiresIn));
    return tokens.accessToken;
  }

  Future<String?> restore() => _refreshing ??= _restoreOnce().whenComplete(() {
    _refreshing = null;
  });

  Future<String?> _restoreOnce() async {
    final api = _api;
    if (api == null) return null;
    final saved = await _store.read();
    if (!kIsWeb && saved == null) return null;
    try {
      final tokens = await api.refresh(saved);
      if (tokens.refreshToken != null) {
        await _store.write(tokens.refreshToken!);
      }
      accessToken = tokens.accessToken;
      _expiresAt = DateTime.now().add(Duration(seconds: tokens.expiresIn));
      return tokens.accessToken;
    } on AuthException {
      await _store.clear();
      accessToken = null;
      _expiresAt = null;
      return null;
    }
  }

  Future<String?> refreshIfNeeded() async {
    final token = accessToken;
    if (token == null) return null;
    final expiresAt = _expiresAt;
    if (expiresAt != null &&
        DateTime.now().isBefore(
          expiresAt.subtract(const Duration(minutes: 5)),
        )) {
      return token;
    }
    return restore();
  }

  Future<void> logout() async {
    final saved = await _store.read();
    try {
      await _api?.logout(saved);
    } finally {
      accessToken = null;
      _expiresAt = null;
      await _store.clear();
    }
  }
}
