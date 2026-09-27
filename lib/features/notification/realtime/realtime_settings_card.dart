import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../push/push_scope.dart';
import 'realtime_config.dart';
import 'realtime_scope.dart';

class RealtimeSettingsCard extends StatefulWidget {
  const RealtimeSettingsCard({super.key});
  @override
  State<RealtimeSettingsCard> createState() => _RealtimeSettingsCardState();
}

class _RealtimeSettingsCardState extends State<RealtimeSettingsCard> {
  final _controller = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String> _deviceId() async {
    final prefs = SharedPreferencesAsync();
    final existing = await prefs.getString('inbbi.device.id');
    if (existing != null) return existing;
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await prefs.setString('inbbi.device.id', id);
    return id;
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final service = RealtimeScope.maybeOf(context);
    if (service == null) return const SizedBox.shrink();
    final configured = RealtimeConfig.configured;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '테스트 서버 실시간 알림',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              configured
                  ? '상태: ${service.status.name}'
                  : 'WSS와 HTTPS 서버 주소를 설정해 주세요.',
            ),
            if (service.error != null)
              Text(service.error!, style: const TextStyle(color: Colors.red)),
            if (configured) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(labelText: '테스트 계정 액세스 토큰'),
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final push = PushScope.maybeOf(context);
                            final token = _controller.text.trim();
                            if (token.isEmpty) return;
                            setState(() => _busy = true);
                            try {
                              await service.start(
                                accessToken: token,
                                deviceId: await _deviceId(),
                              );
                              if (!mounted) return;
                              await service.updateFcmToken(push?.currentToken);
                              _controller.clear();
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: const Text('연결'),
                  ),
                  TextButton(
                    onPressed: service.active ? service.stop : null,
                    child: const Text('연결 해제'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
