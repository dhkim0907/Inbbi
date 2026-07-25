import 'package:flutter/material.dart';

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// 로그인/스플래시 페이지를 제외한 모든 페이지 하단에 표시되는 공통 메뉴 바.
/// 탭 선택 시 어떻게 반응할지는 [onTap]을 통해 호출부에서 결정한다.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  /// 선택된 탭 인덱스. 탭에 해당하지 않는 페이지에서는 -1을 전달한다.
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const Color _selectedColor = Color(0xFF346CB2);
  static const Color _unselectedColor = Color(0xFF9CA3AF);

  static const List<_NavItem> _items = [
    _NavItem(label: '홈', icon: Icons.home_outlined, selectedIcon: Icons.home),
    _NavItem(
      label: '캘린더',
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today,
    ),
    _NavItem(label: '공지', icon: Icons.menu, selectedIcon: Icons.menu),
    _NavItem(
      label: '강의',
      icon: Icons.article_outlined,
      selectedIcon: Icons.article,
    ),
    _NavItem(
      label: '마이',
      icon: Icons.account_circle_outlined,
      selectedIcon: Icons.account_circle,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final selected = index == currentIndex;
            final color = selected ? _selectedColor : _unselectedColor;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => onTap(index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? item.selectedIcon : item.icon,
                      color: color,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
