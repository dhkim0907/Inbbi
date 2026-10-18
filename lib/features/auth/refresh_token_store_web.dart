import 'refresh_token_store.dart';

class CookieRefreshTokenStore implements RefreshTokenStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> clear() async {}
}

RefreshTokenStore createStore() => CookieRefreshTokenStore();
