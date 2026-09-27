import 'dart:convert';
import '../notification_service.dart';

/// WebSocket, FCM, 목록 API가 같은 문서 구조를 사용한다.
AppNotification? parsePush(Map<String, dynamic> data) {
  final id = data['eventId'];
  final title = data['title'];
  final body = data['body'];
  final rawVersion = data['version'] ?? 1;
  final version = rawVersion is int ? rawVersion : int.tryParse('$rawVersion');
  final eventType = data['eventType'];
  final rawTarget = data['target'];
  final target = rawTarget is Map
      ? rawTarget
      : rawTarget is String
      ? _decodeTarget(rawTarget)
      : null;
  final occurredAt = data['occurredAt'] ?? data['createdAt'];
  // 이전 로컬 테스트 페이로드(kind/createdAt)도 읽을 수 있게 둔다.
  final legacyKind = data['kind'];
  final legacy = eventType == null && legacyKind is String;
  if (id is! String ||
      id.isEmpty ||
      id.length > 200 ||
      title is! String ||
      title.isEmpty ||
      title.length > 200 ||
      body is! String ||
      body.length > 2000 ||
      version is! int ||
      version < 1 ||
      occurredAt is! String) {
    return null;
  }
  final date = DateTime.tryParse(occurredAt);
  if (date == null || !date.isUtc) return null;
  if (!legacy &&
      (eventType is! String ||
          eventType.isEmpty ||
          target is! Map ||
          target['type'] is! String ||
          target['id'] is! String ||
          data['deepLink'] is! String)) {
    return null;
  }
  if (legacy &&
      !NotificationKind.values.any((kind) => kind.name == legacyKind)) {
    return null;
  }
  final type = legacy ? '' : eventType as String;
  final kind = legacy
      ? NotificationKind.values.byName(legacyKind)
      : type.startsWith('notice.')
      ? NotificationKind.notice
      : type.startsWith('course.')
      ? NotificationKind.course
      : type.startsWith('schedule.') || type.startsWith('assignment.')
      ? NotificationKind.deadline
      : NotificationKind.other;
  return AppNotification(
    id: id,
    title: title,
    body: body,
    kind: kind,
    createdAt: date,
    version: version,
    eventType: type,
    targetType: legacy ? '' : target!['type'] as String,
    targetId: legacy ? '' : target!['id'] as String,
    deepLink: legacy ? '' : data['deepLink'] as String,
  );
}

Map<String, dynamic>? _decodeTarget(String value) {
  try {
    return Map<String, dynamic>.from(jsonDecode(value) as Map);
  } catch (_) {
    return null;
  }
}
