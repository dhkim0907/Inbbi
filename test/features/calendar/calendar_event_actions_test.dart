import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/features/calendar/app_calendar_api.dart';
import 'package:inbbi/features/calendar/calendar_controller.dart';
import 'package:inbbi/features/calendar/calendar_event.dart';
import 'package:inbbi/features/calendar/calendar_event_draft.dart';
import 'package:inbbi/features/calendar/calendar_event_writer.dart';
import 'package:inbbi/features/calendar/google_calendar_api.dart';
import 'package:inbbi/features/calendar/google_calendar_auth.dart';

class _AppApi implements AppCalendarApi {
  List<CalendarEvent> events = [];
  bool fail = false;
  @override
  Future<List<CalendarEvent>> fetchMonth(DateTime month) async {
    if (fail) throw StateError('offline');
    return events;
  }
}

class _GoogleApi implements GoogleCalendarApi {
  List<CalendarEvent> events = [];
  bool fail = false;
  String? lastToken;
  @override
  Future<GoogleCalendarFetchResult> fetchMonth(
    DateTime month,
    String token,
  ) async {
    if (fail) throw StateError('offline');
    lastToken = token;
    return GoogleCalendarFetchResult(events, events.length);
  }
}

class _Auth implements GoogleCalendarAuth {
  GoogleCalendarAccount? account;
  @override
  bool get configured => true;
  @override
  bool get needsWebButton => false;
  @override
  Stream<GoogleCalendarAccount?> get changes => const Stream.empty();
  @override
  Future<GoogleCalendarAccount?> restore() async => account;
  @override
  Future<GoogleCalendarAccount?> connect() async => account;
  @override
  Future<String?> accessToken({bool interactive = false}) async =>
      account == null ? null : 'test-token';
  @override
  Future<String?> serverAuthorizationCode() async =>
      account == null ? null : 'test-server-code';
  @override
  Future<void> disconnect() async => account = null;
}

class _Writer implements CalendarEventWriter {
  _Writer(this.api, this.googleApi);
  final _AppApi api;
  final _GoogleApi googleApi;
  final calls = <String>[];
  CalendarEvent? event;
  bool failDelete = false;
  @override
  Future<CalendarEvent> create(CalendarEventDraft draft, String token) async =>
      throw UnimplementedError();
  @override
  Future<CalendarEvent> update(
    String id,
    CalendarEventDraft draft,
    String token,
  ) async {
    calls.add('update:$token');
    final current = event!;
    final updated = CalendarEvent(
      id: id,
      source: current.source,
      calendarId: current.calendarId,
      title: draft.title,
      category: draft.category,
      start: draft.start,
      end: draft.end,
      allDay: draft.allDay,
      isCompleted: current.isCompleted,
      memo: draft.memo,
      location: draft.location,
    );
    api.events = [if (current.source == CalendarSource.appServer) updated];
    googleApi.events = [if (current.source == CalendarSource.google) updated];
    return updated;
  }

  @override
  Future<void> delete(String id, String token) async {
    calls.add('delete:$token');
    if (failDelete) throw const CalendarAuthRequired();
    api.events = [];
    googleApi.events = [];
  }
}

void main() {
  for (final kind in ['app', 'serverGoogle', 'google']) {
    test('출처에 맞는 수정·삭제 경로와 인증 및 새로고침 $kind', () async {
      final api = _AppApi();
      final googleApi = _GoogleApi();
      final auth = _Auth()
        ..account = const GoogleCalendarAccount('test', 'test@example.com');
      final writers = [for (var i = 0; i < 3; i++) _Writer(api, googleApi)];
      final event = CalendarEvent(
        id: kind == 'google' ? 'google:primary:id' : 'server:id',
        source: kind == 'google'
            ? CalendarSource.google
            : CalendarSource.appServer,
        calendarId: kind == 'app' ? null : 'primary',
        title: '원본',
        category: '할일',
        isCompleted: true,
        start: DateTime(2026, 10, 9, 15),
        end: DateTime(2026, 10, 9, 16),
        allDay: false,
      );
      final selected = writers[['app', 'serverGoogle', 'google'].indexOf(kind)];
      selected.event = event;
      if (kind == 'google') {
        googleApi.events = [event];
      } else {
        api.events = [event];
      }
      final controller = CalendarController(
        appApi: api,
        session: CalendarSession()..setToken('app-test-token'),
        googleAuth: auth,
        googleApi: googleApi,
        appOnlyWriter: writers[0],
        appWriter: writers[1],
        googleWriter: writers[2],
      )..month = DateTime(2026, 10);
      addTearDown(controller.dispose);
      await controller.initialize();
      final draft = CalendarEventDraft(
        title: '수정본',
        category: '할일',
        start: event.start,
        end: event.end,
        allDay: false,
        memo: '수정 메모',
      );
      final updated = await controller.updateEvent(event, draft);
      expect(controller.events.single.title, '수정본');
      expect(updated.isCompleted, isTrue);
      selected.failDelete = true;
      await expectLater(
        controller.deleteEvent(updated),
        throwsA(isA<CalendarAuthRequired>()),
      );
      expect(controller.events, hasLength(1));
      selected.failDelete = false;
      await controller.deleteEvent(updated);
      expect(controller.events, isEmpty);
      expect(selected.calls, [
        'update:${kind == 'google' ? 'test-token' : 'app-test-token'}',
        'delete:${kind == 'google' ? 'test-token' : 'app-test-token'}',
        'delete:${kind == 'google' ? 'test-token' : 'app-test-token'}',
      ]);
      expect(
        writers
            .where((writer) => writer != selected)
            .every((writer) => writer.calls.isEmpty),
        isTrue,
      );
    });
  }

  test('종일 샘플 수정은 날짜와 완료 상태를 유지하고 삭제는 새로고침 후 복원하지 않는다', () async {
    final event = CalendarEvent(
      id: 'sample:all-day',
      source: CalendarSource.appServer,
      title: '원본',
      category: '과제',
      isCompleted: true,
      start: DateTime.utc(2026, 10, 9),
      end: DateTime.utc(2026, 10, 10),
      allDay: true,
    );
    final controller = CalendarController(
      appApi: _AppApi(),
      session: CalendarSession(),
      googleAuth: _Auth(),
      googleApi: _GoogleApi(),
      sampleEvents: (_) => [event],
    )..month = DateTime(2026, 10);
    addTearDown(controller.dispose);
    final updated = await controller.updateEvent(
      event,
      CalendarEventDraft(
        title: '수정본',
        category: '과제',
        start: DateTime(2026, 10, 10),
        end: DateTime(2026, 10, 11),
        allDay: true,
      ),
    );
    expect(updated.start, DateTime.utc(2026, 10, 10));
    expect(updated.isCompleted, isTrue);
    expect(updated.occursOn(DateTime(2026, 10, 10)), isTrue);
    await controller.refresh();
    expect(controller.events.single.title, '수정본');
    await controller.deleteEvent(updated);
    await controller.refresh();
    expect(controller.events, isEmpty);
  });
}
