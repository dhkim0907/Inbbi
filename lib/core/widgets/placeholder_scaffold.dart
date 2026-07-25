import 'package:flutter/material.dart';
import 'app_bottom_nav_bar.dart';
import 'placeholder_body.dart';

/// 정적 UI 단계에서 각 페이지를 표시하기 위한 임시 스캐폴드.
/// 실제 화면 구현 시 각 feature/pages 파일에서 body를 채워 넣는다.
class PlaceholderScaffold extends StatelessWidget {
  const PlaceholderScaffold({
    super.key,
    required this.title,
    this.showAppBar = true,
    this.bottomNavIndex,
    this.onBottomNavTap,
  });

  final String title;
  final bool showAppBar;

  /// 하단 메뉴 바에서 선택된 탭 인덱스. null이면 메뉴 바를 표시하지 않는다.
  /// 탭에 해당하지 않는 페이지는 -1을 전달한다.
  final int? bottomNavIndex;
  final ValueChanged<int>? onBottomNavTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(title)) : null,
      body: PlaceholderBody(title: title),
      bottomNavigationBar: bottomNavIndex == null
          ? null
          : AppBottomNavBar(
              currentIndex: bottomNavIndex!,
              onTap: onBottomNavTap ?? (_) {},
            ),
    );
  }
}
