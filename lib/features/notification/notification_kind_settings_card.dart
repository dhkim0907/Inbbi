import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/category_tree_selector.dart';
import '../../core/widgets/tree_selection_card.dart';
import 'notification_scope.dart';
import 'notification_service.dart';
import 'realtime/realtime_scope.dart';

class NotificationKindSettingsCard extends StatelessWidget {
  const NotificationKindSettingsCard({super.key});

  static const categories = [
    CategoryNode(
      id: 'academic',
      label: '학사',
      selectable: false,
      children: [
        CategoryNode(id: 'deadline', label: '마감'),
        CategoryNode(id: 'course', label: '강의'),
      ],
    ),
    CategoryNode(
      id: 'information',
      label: '소식',
      selectable: false,
      children: [
        CategoryNode(id: 'notice', label: '맞춤 공지'),
        CategoryNode(id: 'other', label: '기타'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final service = NotificationScope.of(context);
    final realtime = RealtimeScope.maybeOf(context);
    final selectedIds = service.selectedKinds.map((kind) => kind.name).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TreeSelectionCard(
          title: '받을 알림 종류',
          description: '선택한 종류를 알림 목록에 표시하고 새 알림으로 저장해요.',
          categories: categories,
          selectedIds: selectedIds,
          enabled: service.initialized,
          message: realtime != null && !realtime.active
              ? '외부 알림 종류 설정은 알림 서버 연결 후 적용돼요.'
              : null,
          onSelectionChanged: (ids) async {
            await service.setSelectedKinds({
              for (final kind in NotificationKind.values)
                if (ids.contains(kind.name)) kind,
            });
            if (!context.mounted || service.error != null) return;
            await realtime?.updatePreferences();
          },
        ),
        if (service.error != null)
          Text(service.error!, style: const TextStyle(color: AppColors.error)),
        if (realtime?.error == '외부 알림 종류 설정을 서버에 전달하지 못했어요.')
          const Text(
            '외부 알림 설정을 서버에 전달하지 못했어요. 다시 연결해 주세요.',
            style: TextStyle(color: AppColors.error),
          ),
      ],
    );
  }
}
