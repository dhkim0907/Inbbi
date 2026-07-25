import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

/// 정적 UI 단계에서 탭 콘텐츠 영역을 표시하기 위한 임시 본문.
class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title, style: AppTextStyles.heading1),
    );
  }
}
