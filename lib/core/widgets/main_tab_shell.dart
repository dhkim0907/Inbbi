import 'package:flutter/material.dart';
import '../../features/calendar/calendar_page.dart';
import '../../features/course/course_management_page.dart';
import '../../features/home/home_dashboard_page.dart';
import '../../features/notice_feed/notice_feed_page.dart';
import '../../features/notification/notification_page.dart';
import '../../features/settings/settings_page.dart';
import '../layout/app_breakpoints.dart';
import 'app_bottom_nav_bar.dart';
import 'app_navigation_rail.dart';

/// 홈/캘린더/공지/강의/마이 5개 탭 + 알림 화면을 감싸는 단일 고정 셸.
/// Scaffold와 하단 메뉴 바 인스턴스가 하나로 고정되고, 탭 전환은
/// [Navigator]를 거치지 않고 [IndexedStack] 인덱스만 바꿔서 이루어진다.
/// 알림(index 5)은 모바일 하단 바에는 노출되지 않고 데스크톱 사이드 레일에서만
/// 선택 가능하지만, 전환 방식 자체는 다른 탭과 동일하게 인덱스 스위치다.
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
    NotificationPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final screenSize = AppBreakpoints.of(context);
    final content = IndexedStack(index: _index, children: _pages);
    void select(int index) => setState(() => _index = index);

    if (screenSize == ScreenSize.mobile) {
      return Scaffold(
        body: content,
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: _index,
          onTap: select,
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            AppNavigationRail(currentIndex: _index, onTap: select),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
