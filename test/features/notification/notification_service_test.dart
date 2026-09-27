import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/features/notification/notification_service.dart';

class MemoryStorage implements NotificationStorage {
  String? value;
  bool fail = false;
  @override
  Future<String?> load() async {
    if (fail) throw StateError('failed');
    return value;
  }

  @override
  Future<void> save(String value) async {
    if (fail) throw StateError('failed');
    this.value = value;
  }
}

class MemoryKindStorage implements NotificationKindStorage {
  Set<NotificationKind>? value;
  @override
  Future<Set<NotificationKind>?> load() async => value;
  @override
  Future<void> save(Set<NotificationKind> kinds) async => value = Set.of(kinds);
}

AppNotification event(
  String id, {
  NotificationKind kind = NotificationKind.deadline,
}) => AppNotification(
  id: id,
  title: '알림 $id',
  body: '테스트 내용',
  kind: kind,
  createdAt: DateTime(2026, 9, 27),
);

void main() {
  test('수신, 동시 중복 방지, 읽음 및 재시작 복원', () async {
    final storage = MemoryStorage();
    final service = NotificationService(storage);
    await service.initialize();
    await Future.wait([
      service.receive(event('a')),
      service.receive(event('a')),
      service.receive(event('b')),
    ]);
    expect(service.items.length, 2);
    expect(service.unreadCount, 2);
    await service.markRead('a');
    await service.receive(event('a'));
    expect(service.unreadCount, 1);
    final restored = NotificationService(storage);
    await restored.initialize();
    expect(restored.items.length, 2);
    expect(restored.unreadCount, 1);
    await restored.markAllRead();
    final again = NotificationService(storage);
    await again.initialize();
    expect(again.unreadCount, 0);
  });
  test('저장 실패는 상태를 보존하고 다음 요청으로 복구', () async {
    final storage = MemoryStorage();
    final service = NotificationService(storage);
    await service.initialize();
    await service.receive(event('a'));
    storage.fail = true;
    await service.markRead('a');
    expect(service.error, isNotNull);
    expect(service.unreadCount, 1);
    storage.fail = false;
    await service.markRead('a');
    expect(service.error, isNull);
    expect(service.unreadCount, 0);
  });
  test('손상된 저장 데이터는 덮어쓰지 않고 초기화 재시도 가능', () async {
    final storage = MemoryStorage()..value = 'broken';
    final service = NotificationService(storage);
    await service.initialize();
    expect(service.initialized, false);
    await service.receive(event('a'));
    expect(storage.value, 'broken');
    storage.value = null;
    await service.initialize();
    expect(service.initialized, true);
  });
  test('선택한 종류만 저장·표시하고 설정을 재시작 후 복원한다', () async {
    final storage = MemoryStorage();
    final kinds = MemoryKindStorage();
    final service = NotificationService(storage, kindStorage: kinds);
    await service.initialize();
    await service.setSelectedKinds({NotificationKind.deadline});
    await service.receive(event('deadline'));
    await service.receive(event('notice', kind: NotificationKind.notice));
    expect(service.items.map((item) => item.id), ['deadline']);
    expect(service.unreadCount, 1);

    final restored = NotificationService(storage, kindStorage: kinds);
    await restored.initialize();
    expect(restored.selectedKinds, {NotificationKind.deadline});
    expect(restored.items.map((item) => item.id), ['deadline']);
  });
}
