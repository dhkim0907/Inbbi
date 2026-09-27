import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import 'push_gateway.dart';
import 'push_scope.dart';

class PushSettingsCard extends StatelessWidget {
  const PushSettingsCard({super.key});
  @override
  Widget build(BuildContext context) {
    final service = PushScope.maybeOf(context);
    if (service == null) return const SizedBox.shrink();
    final status = !service.configured
        ? '알림 서비스가 아직 준비되지 않았어요.'
        : service.permission == PushPermission.denied
        ? '기기 또는 브라우저에서 알림 권한을 허용해 주세요.'
        : service.enabled
        ? '앱을 사용하지 않을 때도 알림을 받아요.'
        : '일정과 공지 알림을 기기로 받아요.';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('앱 외부 알림'),
              subtitle: Text(status),
              value: service.enabled,
              onChanged: service.initialized && !service.busy
                  ? service.setEnabled
                  : null,
            ),
            if (service.busy) const LinearProgressIndicator(),
            if (service.error != null)
              Text(
                service.error!,
                style: const TextStyle(color: AppColors.error),
              ),
            if (service.configured &&
                !service.busy &&
                (!service.initialized || service.error != null))
              TextButton(
                onPressed: () => service.initialized
                    ? service.setEnabled(service.enabled)
                    : service.initialize(),
                child: const Text('다시 연결'),
              ),
            if (kDebugMode && service.debugToken != null)
              TextButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('테스트 수신 토큰 복사'),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: service.debugToken!),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('테스트 수신 토큰을 복사했어요.')),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
