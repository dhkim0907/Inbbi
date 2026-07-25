import 'package:flutter/material.dart';
import '../../features/calendar/calendar_page.dart';
import '../../features/course/course_management_page.dart';
import '../../features/home/home_dashboard_page.dart';
import '../../features/notice_feed/notice_feed_page.dart';
import '../../features/settings/settings_page.dart';
import 'app_bottom_nav_bar.dart';

/// 홈/캘린더/공지/강의/마이 5개 탭을 감싸는 단일 고정 셸.
/// Scaffold와 하단 메뉴 바 인스턴스가 하나로 고정되고, 탭 전환은
/// [Navigator]를 거치지 않고 [IndexedStack] 인덱스만 바꿔서 이루어진다.
class MainTabShell extends StatefulWidget {
  const MainTabShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainTabShell> createState() => _MainTabShellState();
}

class _MainTabShellState extends State<MainTabShell> {
  late int _index = widget.initialIndex;

  static const List<Widget> _pages = [
    HomeDashboardPage(),
    CalendarPage(),
    NoticeFeedPage(),
    CourseManagementPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
      ),
    );
  }
}
