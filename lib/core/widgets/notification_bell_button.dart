import 'package:flutter/material.dart';
import '../../features/notification/notification_scope.dart';
import '../theme/app_colors.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});
  @override
  Widget build(BuildContext context) {
    final count = NotificationScope.of(context).unreadCount;
    return IconButton.filled(
      tooltip: '알림, 읽지 않은 알림 $count개',
      style: IconButton.styleFrom(backgroundColor: AppColors.primary),
      onPressed: () => NotificationNavigation.open(context, 5),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications),
      ),
    );
  }
}
