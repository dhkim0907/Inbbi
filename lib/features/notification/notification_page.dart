import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import '../../core/widgets/placeholder_scaffold.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  static const List<String> _tabRoutes = [
    AppRoutes.home,
    AppRoutes.calendar,
    AppRoutes.noticeFeed,
    AppRoutes.course,
    AppRoutes.settings,
  ];

  @override
  Widget build(BuildContext context) {
    return PlaceholderScaffold(
      title: '알림',
      bottomNavIndex: -1,
      onBottomNavTap: (index) {
        Navigator.of(context).pushReplacementNamed(_tabRoutes[index]);
      },
    );
  }
}
