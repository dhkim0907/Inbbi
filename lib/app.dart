import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'features/notification/realtime/realtime_config.dart';
import 'features/notification/realtime/realtime_scope.dart';
import 'features/notification/realtime/realtime_service.dart';
import 'features/notification/realtime/realtime_transport.dart';
import 'dart:async';
import 'features/notification/push/push_config.dart';
import 'features/notification/push/push_gateway.dart';
import 'features/notification/push/push_service.dart';
import 'features/notification/push/push_scope.dart';
import 'package:flutter/material.dart';
import 'features/notification/notification_scope.dart';
import 'features/notification/notification_service.dart';
import 'core/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/main_tab_shell.dart';
import 'features/splash/splash_page.dart';
import 'features/auth/login_page.dart';
import 'features/auth/auth_scope.dart';
import 'features/auth/auth_session_service.dart';
import 'features/calendar/app_calendar_api.dart';
import 'features/calendar/calendar_controller.dart';
import 'features/calendar/calendar_scope.dart';
import 'features/calendar/google_calendar_api.dart';
import 'features/calendar/google_calendar_auth.dart';
import 'features/calendar/google_calendar_server_link.dart';
import 'features/calendar/calendar_event_writer.dart';
import 'features/calendar/calendar_sample_events.dart';

class InbbiApp extends StatefulWidget {
  const InbbiApp({super.key});

  @override
  State<InbbiApp> createState() => _InbbiAppState();
}

class _InbbiAppState extends State<InbbiApp> with WidgetsBindingObserver {
  late final PushService _push;
  late final NotificationRealtimeService _realtime;
  String? _syncedFcmToken;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  Set<ConnectivityResult>? _previousNetwork;
  Timer? _networkDebounce;
  Timer? _authRefreshTimer;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final NotificationService _notifications;
  late final CalendarSession _calendarSession;
  late final GoogleSignInCalendarAuth _calendarAuth;
  late final CalendarController _calendar;
  late final AuthSessionService _auth;
  @override
  void initState() {
    super.initState();
    _notifications = NotificationService(
      LocalNotificationStorage(),
      kindStorage: LocalNotificationKindStorage(),
    )..initialize();
    _calendarSession = CalendarSession();
    _calendarAuth = GoogleSignInCalendarAuth();
    const calendarApiUrl = String.fromEnvironment('CALENDAR_API_URL');
    final configuredCalendarUri = Uri.tryParse(calendarApiUrl);
    final calendarBaseUrl =
        configuredCalendarUri != null &&
            configuredCalendarUri.path.endsWith('/') &&
            (configuredCalendarUri.scheme == 'https' ||
                (kDebugMode &&
                    configuredCalendarUri.scheme == 'http' &&
                    (configuredCalendarUri.host == 'localhost' ||
                        configuredCalendarUri.host == '127.0.0.1')))
        ? configuredCalendarUri
        : null;
    _auth = AuthSessionService(baseUrl: calendarBaseUrl);
    _authRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_refreshAppSession()),
    );
    _calendar = CalendarController(
      sampleEvents:
          kDebugMode &&
              const bool.fromEnvironment(
                'CALENDAR_SAMPLE_DATA',
                defaultValue: true,
              )
          ? (month) => calendarSampleEvents(month)
          : null,
      appApi: HttpAppCalendarApi(
        baseUrl: calendarBaseUrl,
        session: _calendarSession,
      ),
      session: _calendarSession,
      googleAuth: _calendarAuth,
      googleApi: HttpGoogleCalendarApi(),
      appWriter: HttpAppCalendarEventWriter(baseUrl: calendarBaseUrl),
      appOnlyWriter: HttpAppCalendarEventWriter(
        baseUrl: calendarBaseUrl,
        appOnly: true,
      ),
      googleWriter: HttpGoogleCalendarEventWriter(),
      serverLink: HttpGoogleCalendarServerLink(
        baseUrl: calendarBaseUrl,
        session: _calendarSession,
      ),
    )..initialize();
    WidgetsBinding.instance.addObserver(this);
    _push = PushService(
      gateway: FirebasePushGateway(),
      notifications: _notifications,
      preferences: LocalPushPreferences(),
      configured: PushConfig.configured,
    );
    _realtime = NotificationRealtimeService(
      url: Uri.parse(
        RealtimeConfig.configured
            ? RealtimeConfig.socketUrl
            : 'wss://localhost.invalid/ws',
      ),
      api: HttpNotificationApi(
        Uri.parse(
          RealtimeConfig.configured
              ? RealtimeConfig.apiUrl
              : 'https://localhost.invalid/',
        ),
      ),
      notifications: _notifications,
      cursorStore: LocalNotificationCursorStore(),
      openSocket: ChannelNotificationSocket.new,
    );
    _push.addListener(_syncPushToken);
    _networkSubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final next = results.toSet();
      final previous = _previousNetwork;
      _previousNetwork = next;
      if (previous == null ||
          setEquals(previous, next) ||
          next.contains(ConnectivityResult.none)) {
        return;
      }
      _networkDebounce?.cancel();
      _networkDebounce = Timer(const Duration(milliseconds: 500), () {
        if (_realtime.active) unawaited(_realtime.reconnect());
      });
    });
    unawaited(_push.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _networkDebounce?.cancel();
    _authRefreshTimer?.cancel();
    unawaited(_networkSubscription?.cancel());
    _push.removeListener(_syncPushToken);
    _realtime.dispose();
    _push.dispose();
    _notifications.dispose();
    _calendar.dispose();
    _calendarAuth.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAppSession());
      _realtime.resume();
      unawaited(_push.resume());
      unawaited(_calendar.refresh());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_realtime.suspend());
    }
  }

  void _syncPushToken() {
    final token = _push.currentToken;
    if (token == _syncedFcmToken) return;
    _syncedFcmToken = token;
    unawaited(_realtime.updateFcmToken(token));
  }

  Future<void> _refreshAppSession() async {
    final previous = _auth.accessToken;
    if (previous == null) return;
    try {
      final current = await _auth.refreshIfNeeded();
      if (current == previous) return;
      _calendar.setAppToken(current);
      if (current == null) {
        await _realtime.stop();
        _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
      } else {
        await _realtime.refreshCredentials(current);
      }
    } catch (_) {
      // Keep the session so a later network retry can restore it.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      service: _auth,
      child: CalendarScope(
        controller: _calendar,
        child: NotificationScope(
          service: _notifications,
          child: PushScope(
            service: _push,
            child: RealtimeScope(
              service: _realtime,
              child: MaterialApp(
                navigatorKey: _navigatorKey,
                title: '인삐',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                initialRoute: AppRoutes.splash,
                routes: {
                  AppRoutes.splash: (context) => const SplashPage(),
                  AppRoutes.login: (context) => const LoginPage(),
                  AppRoutes.home: (context) =>
                      const MainTabShell(initialIndex: 0),
                  AppRoutes.calendar: (context) =>
                      const MainTabShell(initialIndex: 1),
                  AppRoutes.noticeFeed: (context) =>
                      const MainTabShell(initialIndex: 2),
                  AppRoutes.course: (context) =>
                      const MainTabShell(initialIndex: 3),
                  AppRoutes.notification: (context) =>
                      const MainTabShell(initialIndex: 5),
                  AppRoutes.settings: (context) =>
                      const MainTabShell(initialIndex: 4),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
