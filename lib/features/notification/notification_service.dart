import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NotificationKind { deadline, course, notice, other }

abstract interface class NotificationKindStorage {
  Future<Set<NotificationKind>?> load();
  Future<void> save(Set<NotificationKind> kinds);
}

class LocalNotificationKindStorage implements NotificationKindStorage {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  static const _key = 'inbbi.notifications.selectedKinds.v1';

  @override
  Future<Set<NotificationKind>?> load() async {
    final names = await _preferences.getStringList(_key);
    if (names == null) return null;
    return names
        .where(
          (name) => NotificationKind.values.any((kind) => kind.name == name),
        )
        .map(NotificationKind.values.byName)
        .toSet();
  }

  @override
  Future<void> save(Set<NotificationKind> kinds) =>
      _preferences.setStringList(_key, kinds.map((kind) => kind.name).toList());
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.createdAt,
    this.isRead = false,
    this.version = 1,
    this.eventType = '',
    this.targetType = '',
    this.targetId = '',
    this.deepLink = '',
  });
  final String id;
  final String title;
  final String body;
  final NotificationKind kind;
  final DateTime createdAt;
  final bool isRead;
  final int version;
  final String eventType;
  final String targetType;
  final String targetId;
  final String deepLink;
  String get category => switch (kind) {
    NotificationKind.deadline => '마감',
    NotificationKind.course => '강의',
    NotificationKind.notice => '맞춤',
    NotificationKind.other => '기타',
  };
  int get destinationIndex => switch (eventType.split('.').first) {
    'notice' => 2,
    'schedule' => 1,
    'assignment' => 1,
    _ => switch (kind) {
      NotificationKind.deadline => 1,
      NotificationKind.course => 3,
      NotificationKind.notice => 2,
      NotificationKind.other => 5,
    },
  };
  AppNotification read() => AppNotification(
    id: id,
    title: title,
    body: body,
    kind: kind,
    createdAt: createdAt,
    isRead: true,
    version: version,
    eventType: eventType,
    targetType: targetType,
    targetId: targetId,
    deepLink: deepLink,
  );
  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'kind': kind.name,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
    'version': version,
    'eventType': eventType,
    'targetType': targetType,
    'targetId': targetId,
    'deepLink': deepLink,
  };
  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        kind: NotificationKind.values.byName(json['kind'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        isRead: json['isRead'] as bool,
        version: json['version'] as int? ?? 1,
        eventType: json['eventType'] as String? ?? '',
        targetType: json['targetType'] as String? ?? '',
        targetId: json['targetId'] as String? ?? '',
        deepLink: json['deepLink'] as String? ?? '',
      );
}

abstract interface class NotificationStorage {
  Future<String?> load();
  Future<void> save(String value);
}

class LocalNotificationStorage implements NotificationStorage {
  LocalNotificationStorage({this.userId});
  final String? userId;
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  String get _key => userId == null
      ? 'inbbi.notifications.v1'
      : 'inbbi.notifications.v1.${Uri.encodeComponent(userId!)}';
  @override
  Future<String?> load() => _preferences.getString(_key);
  @override
  Future<void> save(String value) => _preferences.setString(_key, value);
}

/// 모든 수신 경로는 동일한 이벤트 ID로 receive를 호출한다.
/// 저장 성공 후에만 상태를 반영하며 작업을 직렬화해 갱신 유실을 방지한다.
class NotificationService extends ChangeNotifier {
  NotificationService(this._storage, {this.accountStorage, this.kindStorage});
  NotificationStorage _storage;
  final NotificationStorage Function(String?)? accountStorage;
  final NotificationKindStorage? kindStorage;
  Set<NotificationKind> _selectedKinds = NotificationKind.values.toSet();
  Set<NotificationKind> get selectedKinds => Set.unmodifiable(_selectedKinds);
  bool accepts(NotificationKind kind) => _selectedKinds.contains(kind);
  NotificationStorage get storage => _storage;
  List<AppNotification> _items = [];
  List<AppNotification> get items =>
      List.unmodifiable(_items.where((item) => accepts(item.kind)));
  int get unreadCount =>
      _items.where((item) => accepts(item.kind) && !item.isRead).length;
  bool initialized = false;
  String? error;
  Future<void> _queue = Future.value();
  bool _disposed = false;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _run(Future<void> Function() operation) {
    final result = _queue.then((_) async {
      try {
        await operation();
        error = null;
      } catch (_) {
        error = '알림을 불러오거나 저장하지 못했어요. 다시 시도해 주세요.';
      }
      _emit();
    });
    _queue = result;
    return result;
  }

  Future<void> initialize() => _run(() async {
    if (initialized) return;
    _selectedKinds =
        await kindStorage?.load() ?? NotificationKind.values.toSet();
    _items = await _readItems(_storage);
    initialized = true;
  });

  Future<void> setSelectedKinds(Set<NotificationKind> kinds) => _run(() async {
    if (!initialized) throw StateError('알림 초기화가 필요합니다.');
    await kindStorage?.save(kinds);
    _selectedKinds = Set.of(kinds);
  });
  Future<List<AppNotification>> _readItems(NotificationStorage source) async {
    final raw = await source.load();
    final restored = raw == null
        ? <AppNotification>[]
        : (jsonDecode(raw) as List)
              .map(
                (value) =>
                    AppNotification.fromJson(value as Map<String, dynamic>),
              )
              .toList();
    final unique = {for (final item in restored) item.id: item};
    return unique.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<bool> activateAccount(String? userId) {
    final result = _queue.then((_) async {
      try {
        final current = _storage;
        final factory = accountStorage;
        if (factory == null && current is! LocalNotificationStorage) {
          return true;
        }
        if (factory == null &&
            (current as LocalNotificationStorage).userId == userId) {
          return true;
        }
        final next =
            factory?.call(userId) ?? LocalNotificationStorage(userId: userId);
        final items = await _readItems(next);
        _storage = next;
        _items = items;
        initialized = true;
        error = null;
        _emit();
        return true;
      } catch (_) {
        error = '계정의 알림을 불러오지 못했어요.';
        _emit();
        return false;
      }
    });
    _queue = result.then((_) {});
    return result;
  }

  Future<void> _save(List<AppNotification> next) async {
    if (!initialized) throw StateError('알림 초기화가 필요합니다.');
    await _storage.save(jsonEncode(next.map((item) => item.toJson()).toList()));
    _items = next;
  }

  Future<void> receive(AppNotification item) async {
    await upsert(item);
  }

  /// eventId + version 기준으로 새 알림이나 더 최신 버전만 저장한다.
  /// 최신 버전 교체 시 읽음 상태는 보존한다.
  Future<bool> upsert(AppNotification item) {
    final result = _queue.then((_) async {
      try {
        if (!initialized) throw StateError('알림 초기화가 필요합니다.');
        if (!accepts(item.kind)) {
          error = null;
          return true;
        }
        final existingIndex = _items.indexWhere((entry) => entry.id == item.id);
        if (existingIndex >= 0 &&
            _items[existingIndex].version >= item.version) {
          error = null;
          return true;
        }
        final existing = existingIndex < 0 ? null : _items[existingIndex];
        final next = <AppNotification>[
          for (final entry in _items)
            if (entry.id != item.id) entry,
          AppNotification(
            id: item.id,
            title: item.title,
            body: item.body,
            kind: item.kind,
            createdAt: item.createdAt,
            isRead: existing?.isRead ?? item.isRead,
            version: item.version,
            eventType: item.eventType,
            targetType: item.targetType,
            targetId: item.targetId,
            deepLink: item.deepLink,
          ),
        ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _save(next);
        error = null;
        _emit();
        return true;
      } catch (_) {
        error = '알림을 불러오거나 저장하지 못했어요. 다시 시도해 주세요.';
        _emit();
        return false;
      }
    });
    _queue = result.then((_) {});
    return result;
  }

  Future<void> markRead(String id) => _run(
    () => _save([
      for (final item in _items)
        if (item.id == id) item.read() else item,
    ]),
  );
  Future<void> markAllRead() => _run(
    () => _save([
      for (final item in _items)
        if (accepts(item.kind)) item.read() else item,
    ]),
  );
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
