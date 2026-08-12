import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_bottom_nav_bar.dart';

/// 데스크톱 너비에서 [AppBottomNavBar] 대신 표시되는 좌측 사이드 내비게이션.
/// [AppBottomNavBar]의 5개 탭에 '알림'을 더한 6개 항목을 모두 동일한 방식
/// ([MainTabShell]의 [IndexedStack] 인덱스 전환)으로 선택한다.
class AppNavigationRail extends StatelessWidget {
  const AppNavigationRail({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// [MainTabShell]에서 '알림' 탭에 부여한 인덱스.
  static const int notificationIndex = 5;

  static const Color _selectedBackground = Color(0xFFEAF1FF);
  static const Color _unselectedTextColor = Color(0xFF374151);

  // AppBottomNavBar.items 순서: 홈, 캘린더, 공지, 강의, 마이.
  // 사이드바에서는 더 설명적인 라벨을 쓴다.
  static const List<String> _labels = ['홈', '캘린더', '공지', '강의 관리', '설정'];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '인삐',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppBottomNavBar.selectedColor,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '오늘의 학사·학습 비서',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < 4; i++)
            _RailItem(
              label: _labels[i],
              selected: i == currentIndex,
              onTap: () => onTap(i),
            ),
          _RailItem(
            label: '알림',
            selected: currentIndex == notificationIndex,
            onTap: () => onTap(notificationIndex),
          ),
          _RailItem(
            label: _labels[4],
            selected: currentIndex == 4,
            onTap: () => onTap(4),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? AppNavigationRail._selectedBackground
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? AppBottomNavBar.selectedColor
                    : AppNavigationRail._unselectedTextColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
