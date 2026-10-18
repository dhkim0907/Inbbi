import 'refresh_token_store_io.dart'
    if (dart.library.js_interop) 'refresh_token_store_web.dart'
    as platform;

abstract interface class RefreshTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

RefreshTokenStore createRefreshTokenStore() => platform.createStore();
