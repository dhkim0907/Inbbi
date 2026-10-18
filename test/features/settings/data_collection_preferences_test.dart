import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/features/settings/data_collection_preferences.dart';

class _MemoryStorage implements DataCollectionPreferenceStorage {
  Set<DataSource>? saved;
  bool failSave = false;

  @override
  Future<Set<DataSource>?> load() async => saved;

  @override
  Future<void> save(Set<DataSource> sources) async {
    if (failSave) throw StateError('save failed');
    saved = Set.of(sources);
  }
}

void main() {
  test('선택한 수집 대상을 저장하고 다시 불러온다', () async {
    final storage = _MemoryStorage();
    final first = DataCollectionPreferences(storage);
    await first.initialize();
    await first.setSelectedSources({DataSource.googleCalendar});
    expect(first.selectedSources, {DataSource.googleCalendar});

    final second = DataCollectionPreferences(storage);
    await second.initialize();
    expect(second.selectedSources, {DataSource.googleCalendar});
    first.dispose();
    second.dispose();
  });

  test('저장 실패 시 이전 선택을 유지한다', () async {
    final storage = _MemoryStorage();
    final preferences = DataCollectionPreferences(storage);
    await preferences.initialize();
    storage.failSave = true;
    await preferences.setSelectedSources({});
    expect(preferences.selectedSources, DataSource.values.toSet());
    expect(preferences.error, isNotNull);
    preferences.dispose();
  });
}
