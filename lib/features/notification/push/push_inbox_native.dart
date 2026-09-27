import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _prefix = 'inbbi.push.inbox.';
Future<void> savePendingPush(Map<String, dynamic> data) async {
  final id = data['eventId'] as String;
  await SharedPreferencesAsync().setString(
    '$_prefix${Uri.encodeComponent(id)}',
    jsonEncode(data),
  );
}

Future<List<Map<String, dynamic>>> loadPendingPushes() async {
  final prefs = SharedPreferencesAsync();
  final keys = (await prefs.getKeys())
      .where((key) => key.startsWith(_prefix))
      .toSet();
  if (keys.isEmpty) return [];
  final values = await prefs.getAll(allowList: keys);
  return values.values
      .map(
        (value) =>
            Map<String, dynamic>.from(jsonDecode(value as String) as Map),
      )
      .toList();
}

Future<void> removePendingPush(String id) =>
    SharedPreferencesAsync().remove('$_prefix${Uri.encodeComponent(id)}');
Stream<void> watchPushOpened() => const Stream.empty();
