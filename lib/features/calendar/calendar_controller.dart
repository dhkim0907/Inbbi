import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_calendar_api.dart';
import 'calendar_event.dart';
import 'google_calendar_api.dart';
import 'google_calendar_auth.dart';

class CalendarController extends ChangeNotifier {
  CalendarController({
    required this.appApi,
    required this.session,
    required this.googleAuth,
    required this.googleApi,
  });

  final AppCalendarApi appApi;
  final CalendarSession session;
  final GoogleCalendarAuth googleAuth;
  final GoogleCalendarApi googleApi;
  StreamSubscription<GoogleCalendarAccount?>? _accountSubscription;
  List<CalendarEvent> _appEvents = [];
  List<CalendarEvent> _googleEvents = [];
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  GoogleCalendarAccount? googleAccount;
  bool appLoading = false;
  bool appLoaded = false;
  bool googleLoading = false;
  bool googleLoaded = false;
  int googleReceivedCount = 0;
  bool googleAuthorizationRequired = false;
  bool googleReady = false;
  String? appError;
  String? googleError;
  int _generation = 0;
  bool _disposed = false;

  List<CalendarEvent> get events => [
    ..._appEvents.where((event) => event.overlapsMonth(month)),
    ..._googleEvents.where((event) => event.overlapsMonth(month)),
  ]..sort((a, b) => a.start.compareTo(b.start));

  Set<int> get eventDays => {
    for (
      var day = 1;
      day <= DateTime(month.year, month.month + 1, 0).day;
      day++
    )
      if (events.any(
        (event) => event.occursOn(DateTime(month.year, month.month, day)),
      ))
        day,
  };

  int get googleEventCount =>
      _googleEvents.where((event) => event.overlapsMonth(month)).length;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    _accountSubscription ??= googleAuth.changes.listen((value) {
      if (value?.id == googleAccount?.id) return;
      googleAccount = value;
      _googleEvents = [];
      googleLoaded = false;
      googleReceivedCount = 0;
      googleAuthorizationRequired = value != null;
      _emit();
      if (value != null) unawaited(refreshGoogle());
    });
    await refreshApp();
    try {
      final restored = await googleAuth.restore();
      googleReady = true;
      if (restored != null && googleAccount?.id != restored.id) {
        googleAccount = restored;
        await refreshGoogle();
      }
    } catch (_) {
      googleReady = true;
      googleError = 'Google 계정을 복원하지 못했어요.';
      _emit();
    }
  }

  Future<void> setMonth(DateTime value) async {
    month = DateTime(value.year, value.month, 1);
    _generation++;
    _appEvents = [];
    _googleEvents = [];
    googleLoaded = false;
    googleReceivedCount = 0;
    _emit();
    await Future.wait([refreshApp(), refreshGoogle()]);
  }

  Future<void> refresh() async {
    await Future.wait([refreshApp(), refreshGoogle()]);
  }

  Future<void> refreshApp() async {
    final requestMonth = month;
    final generation = _generation;
    appLoading = true;
    appError = null;
    _emit();
    try {
      final fetched = await appApi.fetchMonth(requestMonth);
      if (generation == _generation) {
        _appEvents = fetched;
        appLoaded = true;
      }
    } on CalendarUnavailable {
      appLoaded = false;
    } on CalendarAuthRequired {
      appError = '일정 서버 로그인이 필요해요.';
    } catch (_) {
      appError = '서버 일정을 불러오지 못했어요. 다시 시도해 주세요.';
    } finally {
      appLoading = false;
      _emit();
    }
  }

  Future<void> refreshGoogle({bool interactive = false}) async {
    final account = googleAccount;
    if (account == null) return;
    final requestMonth = month;
    final generation = _generation;
    googleLoading = true;
    googleError = null;
    _emit();
    try {
      final token = await googleAuth.accessToken(interactive: interactive);
      if (token == null) {
        googleAuthorizationRequired = true;
        return;
      }
      googleAuthorizationRequired = false;
      final fetched = await googleApi.fetchMonth(requestMonth, token);
      if (generation == _generation && googleAccount?.id == account.id) {
        _googleEvents = fetched.events;
        googleReceivedCount = fetched.receivedCount;
        googleLoaded = true;
        if (fetched.receivedCount > 0 && fetched.events.isEmpty) {
          googleError = 'Google에서 일정을 받았지만 날짜 형식을 읽지 못했어요.';
        }
      }
    } on GoogleCalendarAuthRequired {
      googleAuthorizationRequired = true;
      googleError = 'Google 일정 권한이 만료되었어요.';
    } on GoogleCalendarAccessDenied {
      googleError =
          'Google 일정 접근이 거부됐어요(403). Calendar API와 OAuth 동의 설정을 확인해 주세요.';
    } catch (_) {
      googleError = 'Google 일정을 불러오지 못했어요. 서버 일정은 계속 표시해요.';
    } finally {
      googleLoading = false;
      _emit();
    }
  }

  void setAppToken(String? token) {
    session.setToken(token);
    _generation++;
    _appEvents = [];
    appLoaded = false;
    _emit();
    unawaited(refreshApp());
  }

  Future<void> connectGoogle() async {
    try {
      final account = await googleAuth.connect();
      if (account == null) return;
      googleAccount = account;
      await authorizeGoogle();
    } catch (_) {
      googleError = 'Google 계정을 연결하지 못했어요.';
      _emit();
    }
  }

  Future<void> authorizeGoogle() => refreshGoogle(interactive: true);

  Future<void> disconnectGoogle() async {
    try {
      await googleAuth.disconnect();
      googleAccount = null;
      _googleEvents = [];
      googleLoaded = false;
      googleReceivedCount = 0;
      googleError = null;
      googleAuthorizationRequired = false;
      _emit();
    } catch (_) {
      googleError = 'Google 연결을 해제하지 못했어요.';
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_accountSubscription?.cancel());
    super.dispose();
  }
}
