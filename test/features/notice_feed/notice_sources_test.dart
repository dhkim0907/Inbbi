import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/features/notice_feed/notice_sources.dart';

class MemoryNoticeStorage implements NoticeSourceStorage {
  String? value;
  bool fail = false;
  @override
  Future<String?> load() async => value;
  @override
  Future<void> save(String data) async {
    if (fail) throw StateError('offline');
    value = data;
  }
}

void main() {
  test('등록·수정·수집 일시정지 설정을 재실행 후 복원한다', () async {
    final storage = MemoryNoticeStorage();
    final sources = NoticeSources(storage);
    addTearDown(sources.dispose);
    await sources.initialize();
    const source = NoticeSource(
      id: 'test',
      name: '테스트 게시판',
      color: 0xFF3674BF,
      url: 'https://example.com/test',
    );
    expect(await sources.put(source), true);
    expect(
      await sources.put(
        source.copyWith(
          name: '새 이름',
          color: 0xFF15939E,
          enabled: false,
          dateSelector: '',
        ),
      ),
      true,
    );
    final restored = NoticeSources(storage);
    addTearDown(restored.dispose);
    await restored.initialize();
    final result = restored.sources.singleWhere((s) => s.id == 'test');
    expect(result.name, '새 이름');
    expect(result.color, 0xFF15939E);
    expect(result.enabled, false);
    expect(result.dateSelector, isEmpty);
  });

  test('이름·URL 중복과 잘못된 URL을 거부한다', () async {
    final sources = NoticeSources(MemoryNoticeStorage());
    addTearDown(sources.dispose);
    await sources.initialize();
    for (final source in [
      const NoticeSource(
        id: 'test',
        name: '학교',
        color: 0xFF3674BF,
        url: 'https://example.com/new',
      ),
      const NoticeSource(
        id: 'test',
        name: '중복 URL',
        color: 0xFF3674BF,
        url: 'https://example.com/clubs/notices',
      ),
      const NoticeSource(
        id: 'test',
        name: '실행 불가',
        color: 0xFF3674BF,
        url: 'javascript:alert(1)',
      ),
    ]) {
      expect(await sources.put(source), false);
    }
    expect(sources.sources, hasLength(7));
  });

  test('저장 실패 시 기존 설정을 유지하고 재시도한다', () async {
    final storage = MemoryNoticeStorage();
    final sources = NoticeSources(storage);
    addTearDown(sources.dispose);
    await sources.initialize();
    final original = sources.sources.last;
    storage.fail = true;
    expect(await sources.put(original.copyWith(enabled: false)), false);
    expect(sources.sources.last.enabled, true);
    expect(sources.error, isNotNull);
    storage.fail = false;
    expect(await sources.put(original.copyWith(enabled: false)), true);
    expect(sources.error, isNull);
  });

  test('기본 분류는 삭제하지 않고 추가 분류 삭제는 영속화한다', () async {
    final storage = MemoryNoticeStorage();
    final sources = NoticeSources(storage);
    addTearDown(sources.dispose);
    await sources.initialize();
    expect(await sources.remove('school'), false);
    expect(await sources.remove('club'), true);
    final restored = NoticeSources(storage);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.sources.any((s) => s.id == 'club'), false);
    expect(restored.sources.any((s) => s.id == 'school'), true);
  });

  test('손상된 저장값은 덮어쓰지 않고 재읽기를 허용한다', () async {
    final storage = MemoryNoticeStorage()..value = '{invalid';
    final sources = NoticeSources(storage);
    addTearDown(sources.dispose);
    await sources.initialize();
    expect(sources.ready, false);
    expect(sources.error, isNotNull);
    expect(await sources.remove('club'), false);
    expect(storage.value, '{invalid');
    storage.value = null;
    await sources.initialize();
    expect(sources.ready, true);
  });
}
