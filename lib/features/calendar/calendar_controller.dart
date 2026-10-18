import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_calendar_api.dart';
import 'calendar_event.dart';
import 'calendar_event_draft.dart';
import 'calendar_event_writer.dart';
import 'google_calendar_api.dart';
import 'google_calendar_auth.dart';
import 'google_calendar_server_link.dart';

class CalendarController extends ChangeNotifier {
  CalendarController({
    required this.appApi,
    required this.session,
    required this.googleAuth,
    required this.googleApi,
    this.serverLink,
    this.appWriter,
    this.appOnlyWriter,
    this.googleWriter,
    this.sampleEvents,
  });

  final AppCalendarApi appApi;
  final CalendarSession session;
  final GoogleCalendarAuth googleAuth;
  final GoogleCalendarApi googleApi;
  final GoogleCalendarServerLink? serverLink;
  final CalendarEventWriter? appWriter;
  final CalendarEventWriter? appOnlyWriter;
  final CalendarEventWriter? googleWriter;
  final List<CalendarEvent> Function(DateTime month)? sampleEvents;
  StreamSubscription<GoogleCalendarAccount?>? _accountSubscription;
  final Map<String, CalendarEvent> _editedSamples = {};
  final Set<String> _deletedSamples = {};
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
  String? serverLinkError;
  bool serverLinkBusy = false;
  bool serverLinked = false;
  bool get serverConnectionAvailable =>
      session.token != null && serverLink?.configured == true;
  int _generation = 0;
  bool _disposed = false;

  List<CalendarEvent> get events => [
    ...?sampleEvents
        ?.call(month)
        .where(
          (event) =>
              !_editedSamples.containsKey(event.id) &&
              !_deletedSamples.contains(event.id),
        ),
    ..._editedSamples.values.where((event) => event.overlapsMonth(month)),
    ..._appEvents.where((event) => event.overlapsMonth(month)),
    if (!serverLinked)
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
      if (value != null) {
        if (serverConnectionAvailable) {
          unawaited(connectGoogleToServer());
        } else {
          unawaited(refreshGoogle());
        }
      }
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

  Future<CalendarEvent> createEvent(CalendarEventDraft draft) async {
    if (draft.saveTarget == CalendarSaveTarget.googleCalendar) {
      return createGoogleEvent(draft);
    }
    final writer = appOnlyWriter;
    if (writer == null) throw const CalendarUnavailable();
    final result = await writer.create(draft, _appToken);
    await refreshApp();
    return result;
  }

  /// Creates an event on the connected user's primary Google calendar.
  Future<CalendarEvent> createGoogleEvent(CalendarEventDraft draft) async {
    final result = serverLinked
        ? await _serverWriter.create(draft, _appToken)
        : await _directWriter.create(draft, await _googleToken);
    await refresh();
    return result;
  }

  /// [eventId] must come from this calendar's Google/server event list.
  Future<CalendarEvent> updateGoogleEvent(
    String eventId,
    CalendarEventDraft draft,
  ) async {
    final result = serverLinked
        ? await _serverWriter.update(eventId, draft, _appToken)
        : await _directWriter.update(eventId, draft, await _googleToken);
    await refresh();
    return result;
  }

  Future<CalendarEvent> updateEvent(
    CalendarEvent event,
    CalendarEventDraft draft,
  ) async {
    if (event.id.startsWith('sample:') && sampleEvents != null) {
      final updated = CalendarEvent(
        id: event.id,
        source: event.source,
        calendarId: event.calendarId,
        title: draft.title,
        category: draft.category,
        start: draft.allDay
            ? DateTime.utc(draft.start.year, draft.start.month, draft.start.day)
            : draft.start,
        end: draft.allDay
            ? DateTime.utc(draft.end.year, draft.end.month, draft.end.day)
            : draft.end,
        allDay: draft.allDay,
        isCompleted: event.isCompleted,
        location: draft.location,
        memo: draft.memo,
      );
      _editedSamples[event.id] = updated;
      _emit();
      return updated;
    }
    final writer = _writerFor(event);
    final token = event.source == CalendarSource.google
        ? await _googleToken
        : _appToken;
    final updated = await writer.update(event.id, draft, token);
    _appEvents = [
      for (final item in _appEvents)
        if (item.id == event.id) updated else item,
    ];
    _googleEvents = [
      for (final item in _googleEvents)
        if (item.id == event.id) updated else item,
    ];
    _emit();
    await refresh();
    return updated;
  }

  Future<void> deleteEvent(CalendarEvent event) async {
    if (event.id.startsWith('sample:') && sampleEvents != null) {
      _editedSamples.remove(event.id);
      _deletedSamples.add(event.id);
      _emit();
      return;
    }
    final writer = _writerFor(event);
    final token = event.source == CalendarSource.google
        ? await _googleToken
        : _appToken;
    await writer.delete(event.id, token);
    _appEvents = _appEvents.where((item) => item.id != event.id).toList();
    _googleEvents = _googleEvents.where((item) => item.id != event.id).toList();
    _emit();
    await refresh();
  }

  CalendarEventWriter _writerFor(CalendarEvent event) {
    if (event.source == CalendarSource.google) return _directWriter;
    if (event.calendarId == 'primary') return _serverWriter;
    if (event.calendarId != null) throw const CalendarUnavailable();
    return appOnlyWriter ?? (throw const CalendarUnavailable());
  }

  CalendarEventWriter get _serverWriter =>
      appWriter ?? (throw const CalendarUnavailable());
  CalendarEventWriter get _directWriter =>
      googleWriter ?? (throw const CalendarUnavailable());
  String get _appToken => session.token ?? (throw const CalendarAuthRequired());
  Future<String> get _googleToken async =>
      await googleAuth.accessToken() ??
      (throw const GoogleCalendarAuthRequired());

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
    if (serverLinked) return;
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
    serverLinked = false;
    _emit();
    unawaited(_refreshServerLinkThenEvents());
  }

  Future<void> _refreshServerLinkThenEvents() async {
    final link = serverLink;
    if (link != null && link.configured && session.token != null) {
      try {
        serverLinked = await link.isConnected();
      } catch (_) {
        serverLinkError = '일정 서버 연결 상태를 확인하지 못했어요.';
      }
      _emit();
    }
    await refreshApp();
  }

  Future<void> connectGoogle() async {
    googleError = null;
    _emit();
    try {
      final account = await googleAuth.connect();
      if (account == null) return;
      googleAccount = account;
      if (!kIsWeb && serverConnectionAvailable && !serverLinked) {
        await connectGoogleToServer();
      }
      if (!serverConnectionAvailable && !kIsWeb) await authorizeGoogle();
    } catch (_) {
      googleError = 'Google 계정을 연결하지 못했어요.';
      _emit();
    }
  }

  Future<void> authorizeGoogle() => refreshGoogle(interactive: true);

  /// Call from a user gesture after app authentication is available.
  Future<void> connectGoogleToServer() async {
    final link = serverLink;
    if (link == null || !link.configured || session.token == null) {
      serverLinkError = '일정 서버 로그인이 필요해요.';
      _emit();
      return;
    }
    if (googleAccount == null || serverLinkBusy) return;
    serverLinkBusy = true;
    serverLinkError = null;
    _emit();
    try {
      final code = await googleAuth.serverAuthorizationCode();
      if (code == null) {
        serverLinkError = 'Google 서버 연결 권한을 받지 못했어요. 다시 시도해 주세요.';
        return;
      }
      await link.connect(code);
      serverLinked = true;
      googleAuthorizationRequired = false;
      await refreshApp();
    } on GoogleServerLinkAuthRequired {
      serverLinkError = '일정 서버 로그인이 필요해요.';
    } catch (_) {
      serverLinkError = 'Google 계정을 일정 서버에 연결하지 못했어요.';
    } finally {
      serverLinkBusy = false;
      _emit();
    }
  }

  Future<void> disconnectGoogleFromServer() async {
    final link = serverLink;
    if (link == null || !link.configured || session.token == null) return;
    await link.disconnect();
    serverLinked = false;
    _appEvents = [];
    _emit();
    await Future.wait([refreshApp(), refreshGoogle()]);
  }

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
