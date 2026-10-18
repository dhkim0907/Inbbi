import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DataSource { portal, iClass, googleCalendar }

abstract interface class DataCollectionPreferenceStorage {
  Future<Set<DataSource>?> load();
  Future<void> save(Set<DataSource> sources);
}

class LocalDataCollectionPreferenceStorage
    implements DataCollectionPreferenceStorage {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  static const _key = 'inbbi.dataCollection.sources.v1';

  @override
  Future<Set<DataSource>?> load() async {
    final names = await _preferences.getStringList(_key);
    if (names == null) return null;
    return names
        .where((name) => DataSource.values.any((source) => source.name == name))
        .map(DataSource.values.byName)
        .toSet();
  }

  @override
  Future<void> save(Set<DataSource> sources) => _preferences.setStringList(
    _key,
    sources.map((source) => source.name).toList(),
  );
}

/// 수집 대상 선택만 관리한다. 실제 수집 실행은 각 연동 서비스가 담당한다.
class DataCollectionPreferences extends ChangeNotifier {
  DataCollectionPreferences(this._storage);

  final DataCollectionPreferenceStorage _storage;
  Set<DataSource> _selectedSources = DataSource.values.toSet();
  Set<DataSource> get selectedSources => Set.unmodifiable(_selectedSources);
  bool initialized = false;
  bool busy = false;
  String? error;
  bool _disposed = false;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> initialize() async {
    if (initialized) return;
    busy = true;
    _emit();
    try {
      _selectedSources = await _storage.load() ?? DataSource.values.toSet();
      initialized = true;
      error = null;
    } catch (_) {
      error = '수집 대상 설정을 불러오지 못했어요.';
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> setSelectedSources(Set<DataSource> sources) async {
    if (!initialized || busy) return;
    busy = true;
    _emit();
    try {
      await _storage.save(sources);
      _selectedSources = Set.of(sources);
      error = null;
    } catch (_) {
      error = '수집 대상 설정을 저장하지 못했어요.';
    } finally {
      busy = false;
      _emit();
    }
  }
}
