import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'refresh_token_store.dart';

class SecureRefreshTokenStore implements RefreshTokenStore {
  static const _key = 'inbbi.test_auth.refresh_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

RefreshTokenStore createStore() => SecureRefreshTokenStore();
