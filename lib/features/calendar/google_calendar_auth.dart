import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

const calendarEventsScope = 'https://www.googleapis.com/auth/calendar.events';
const _googleEmailScope = 'https://www.googleapis.com/auth/userinfo.email';

class GoogleCalendarAccount {
  const GoogleCalendarAccount(this.id, this.email);
  final String id;
  final String email;
}

abstract interface class GoogleCalendarAuth {
  bool get configured;
  bool get needsWebButton;
  Stream<GoogleCalendarAccount?> get changes;
  Future<GoogleCalendarAccount?> restore();
  Future<GoogleCalendarAccount?> connect();
  Future<String?> accessToken({bool interactive = false});
  Future<String?> serverAuthorizationCode();
  Future<void> disconnect();
}

class GoogleSignInCalendarAuth implements GoogleCalendarAuth {
  static const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  final _google = GoogleSignIn.instance;
  final _changes = StreamController<GoogleCalendarAccount?>.broadcast();
  GoogleSignInAccount? _account;
  GoogleCalendarAccount? _webAccount;
  Future<void>? _ready;

  @override
  bool get configured => kIsWeb
      ? webClientId.isNotEmpty
      : defaultTargetPlatform == TargetPlatform.iOS
      ? iosClientId.isNotEmpty
      : webClientId.isNotEmpty;

  @override
  bool get needsWebButton => false;

  @override
  Stream<GoogleCalendarAccount?> get changes => _changes.stream;

  Future<void> _initialize() => _ready ??= _doInitialize();

  Future<void> _doInitialize() async {
    if (!configured) return;
    await _google.initialize(
      clientId: kIsWeb
          ? webClientId
          : defaultTargetPlatform == TargetPlatform.iOS
          ? iosClientId
          : null,
      serverClientId: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? webClientId
          : null,
    );
    _google.authenticationEvents.listen(
      (event) {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn():
            _account = event.user;
            _changes.add(
              GoogleCalendarAccount(event.user.id, event.user.email),
            );
          case GoogleSignInAuthenticationEventSignOut():
            _account = null;
            _webAccount = null;
            _changes.add(null);
        }
      },
      onError: (Object _) {
        _account = null;
        _changes.add(null);
      },
    );
  }

  @override
  Future<GoogleCalendarAccount?> restore() async {
    await _initialize();
    if (!configured) return null;
    final result = await _google.attemptLightweightAuthentication();
    if (result != null) _account = result;
    final account = _account;
    return account == null
        ? null
        : GoogleCalendarAccount(account.id, account.email);
  }

  @override
  Future<GoogleCalendarAccount?> connect() async {
    await _initialize();
    if (!configured) return null;
    if (kIsWeb) {
      final authorization = await _google.authorizationClient.authorizeScopes([
        calendarEventsScope,
        _googleEmailScope,
      ]);
      final response = await http
          .get(
            Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
            headers: {'Authorization': 'Bearer ${authorization.accessToken}'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw StateError('Google account lookup failed');
      }
      final profile = jsonDecode(response.body) as Map<String, dynamic>;
      final id = profile['sub'];
      final email = profile['email'];
      if (id is! String || email is! String) {
        throw const FormatException('Invalid Google account profile');
      }
      _webAccount = GoogleCalendarAccount(id, email);
      _changes.add(_webAccount);
      return _webAccount;
    }
    if (!_google.supportsAuthenticate()) return null;
    final account = await _google.authenticate(
      scopeHint: [calendarEventsScope],
    );
    _account = account;
    return GoogleCalendarAccount(account.id, account.email);
  }

  @override
  Future<String?> accessToken({bool interactive = false}) async {
    await _initialize();
    final account = _account;
    if (account == null && (!kIsWeb || _webAccount == null)) return null;
    final client = kIsWeb
        ? _google.authorizationClient
        : account!.authorizationClient;
    final authorization =
        await client.authorizationForScopes([calendarEventsScope]) ??
        (interactive
            ? await client.authorizeScopes([calendarEventsScope])
            : null);
    return authorization?.accessToken;
  }

  @override
  Future<String?> serverAuthorizationCode() async {
    await _initialize();
    final account = _account;
    if (account == null && (!kIsWeb || _webAccount == null)) return null;
    final client = kIsWeb
        ? _google.authorizationClient
        : account!.authorizationClient;
    final authorization = await client.authorizeServer([calendarEventsScope]);
    return authorization?.serverAuthCode;
  }

  @override
  Future<void> disconnect() async {
    await _initialize();
    if (configured) await _google.disconnect();
    _account = null;
    _webAccount = null;
    _changes.add(null);
  }

  void dispose() => _changes.close();
}
