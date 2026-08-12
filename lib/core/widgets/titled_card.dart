import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 제목 + 내용으로 구성된 흰색 테두리 카드. 내용 높이만큼만 차지한다.
/// 홈 대시보드/공지 모아보기 데스크톱 레이아웃에서 공통으로 쓰인다.
class TitledCard extends StatelessWidget {
  const TitledCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  static const Color _borderColor = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
