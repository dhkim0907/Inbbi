import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class NoticeSourceStorage {
  Future<String?> load();
  Future<void> save(String value);
}

class PreferencesNoticeSourceStorage implements NoticeSourceStorage {
  static const _key = 'inbbi.notice_sources.v1';

  @override
  Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> save(String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(_key, value)) {
      throw StateError('공지 설정 저장 실패');
    }
  }
}

class NoticeSource {
  const NoticeSource({
    required this.id,
    required this.name,
    required this.color,
    this.url = '',
    this.builtIn = false,
    this.enabled = true,
    this.rowSelector = '.sample-row',
    this.titleSelector = 'a',
    this.linkSelector = 'a',
    this.dateSelector = 'time',
  });

  final String id;
  final String name;
  final int color;
  final String url;
  final bool builtIn;
  final bool enabled;
  final String rowSelector;
  final String titleSelector;
  final String linkSelector;
  final String dateSelector;

  NoticeSource copyWith({
    String? name,
    int? color,
    String? url,
    bool? enabled,
    String? rowSelector,
    String? titleSelector,
    String? linkSelector,
    String? dateSelector,
  }) => NoticeSource(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    url: url ?? this.url,
    builtIn: builtIn,
    enabled: enabled ?? this.enabled,
    rowSelector: rowSelector ?? this.rowSelector,
    titleSelector: titleSelector ?? this.titleSelector,
    linkSelector: linkSelector ?? this.linkSelector,
    dateSelector: dateSelector ?? this.dateSelector,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'url': url,
    'builtIn': builtIn,
    'enabled': enabled,
    'row': rowSelector,
    'title': titleSelector,
    'link': linkSelector,
    'date': dateSelector,
  };

  factory NoticeSource.fromJson(Map<String, dynamic> value) => NoticeSource(
    id: value['id'] as String,
    name: value['name'] as String,
    color: value['color'] as int,
    url: value['url'] as String,
    builtIn: value['builtIn'] as bool,
    enabled: value['enabled'] as bool,
    rowSelector: value['row'] as String,
    titleSelector: value['title'] as String,
    linkSelector: value['link'] as String,
    dateSelector: value['date'] as String,
  );
}

/// Figma 예시 게시판의 로컬 설정만 관리한다. 외부 사이트를 수집하지 않는다.
class NoticeSources extends ChangeNotifier {
  NoticeSources(this.storage);
  final NoticeSourceStorage storage;
  List<NoticeSource> _sources = List.of(defaults);
  List<NoticeSource> get sources => List.unmodifiable(_sources);
  bool ready = false;
  bool busy = false;
  String? error;
  bool _disposed = false;

  static const colors = [
    0xFF3674BF,
    0xFF7560C5,
    0xFF15939E,
    0xFF25966C,
    0xFFB58320,
    0xFFCC7245,
    0xFFC26496,
    0xFF748196,
  ];
  static const defaults = [
    NoticeSource(id: 'all', name: '전체', color: 0xFF3674BF, builtIn: true),
    NoticeSource(id: 'school', name: '학교', color: 0xFF3674BF, builtIn: true),
    NoticeSource(
      id: 'department',
      name: '학과',
      color: 0xFF25966C,
      builtIn: true,
    ),
    NoticeSource(
      id: 'scholarship',
      name: '장학',
      color: 0xFFB58320,
      builtIn: true,
    ),
    NoticeSource(
      id: 'club',
      name: '동아리',
      color: 0xFF15939E,
      url: 'https://example.com/clubs/notices',
    ),
    NoticeSource(
      id: 'career',
      name: '취업지원',
      color: 0xFFC26496,
      url: 'https://example.com/career/notices',
    ),
    NoticeSource(
      id: 'global',
      name: '국제교류',
      color: 0xFF7560C5,
      url: 'https://example.com/global/notices',
    ),
  ];

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (ready || busy) return;
    busy = true;
    _emit();
    try {
      final raw = await storage.load();
      if (_disposed) return;
      if (raw != null) {
        final value = jsonDecode(raw) as Map<String, dynamic>;
        if (value['version'] != 1) throw const FormatException();
        final loaded = (value['sources'] as List)
            .map((v) => NoticeSource.fromJson(v as Map<String, dynamic>))
            .toList();
        final builtIns = defaults
            .where((s) => s.builtIn)
            .map((s) => s.id)
            .toSet();
        if (loaded.map((s) => s.id).toSet().length != loaded.length ||
            !builtIns.every(
              (id) => loaded.any((s) => s.id == id && s.builtIn),
            ) ||
            loaded.any(
              (s) =>
                  s.name.trim().isEmpty ||
                  s.color < 0 ||
                  s.color > 0xFFFFFFFF ||
                  s.builtIn != builtIns.contains(s.id) ||
                  (!s.builtIn && !validUrl(s.url)),
            )) {
          throw const FormatException();
        }
        _sources = loaded;
      }
      ready = true;
      error = null;
    } catch (_) {
      error = '공지 설정을 불러오지 못했어요. 다시 시도해 주세요.';
    } finally {
      busy = false;
      _emit();
    }
  }

  static bool validUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        ['http', 'https'].contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  Future<bool> put(NoticeSource source) async {
    if (!ready || busy) return false;
    final existing = _sources.where((s) => s.id == source.id).firstOrNull;
    if (source.name.trim().isEmpty ||
        source.name.length > 40 ||
        (!source.builtIn && !validUrl(source.url)) ||
        (existing == null && source.builtIn) ||
        (existing != null && source.builtIn != existing.builtIn) ||
        _sources.any(
          (s) =>
              s.id != source.id &&
              (s.name == source.name.trim() ||
                  (!source.builtIn && s.url == source.url.trim())),
        )) {
      error = '이름과 URL을 확인해 주세요. 같은 수집처는 중복 등록할 수 없어요.';
      _emit();
      return false;
    }
    return _save([
      for (final s in _sources) s.id == source.id ? source : s,
      if (existing == null) source,
    ]);
  }

  Future<bool> remove(String id) async {
    if (!ready || busy || !_sources.any((s) => s.id == id && !s.builtIn)) {
      return false;
    }
    return _save(_sources.where((s) => s.id != id).toList());
  }

  Future<bool> _save(List<NoticeSource> next) async {
    busy = true;
    error = null;
    _emit();
    try {
      await storage.save(
        jsonEncode({
          'version': 1,
          'sources': next.map((s) => s.toJson()).toList(),
        }),
      );
      if (_disposed) return false;
      _sources = next;
      return true;
    } catch (_) {
      error = '공지 설정을 저장하지 못했어요. 다시 시도해 주세요.';
      return false;
    } finally {
      busy = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
