import 'package:flutter/material.dart';

/// 넓은 화면에서 콘텐츠가 끝없이 늘어나지 않도록 중앙 정렬 + 최대 너비를 제한한다.
/// 좁은 화면에서는 제약이 실질적으로 아무 영향을 주지 않으므로 항상 감싸도 안전하다.
class MaxWidthBody extends StatelessWidget {
  const MaxWidthBody({super.key, required this.child, this.maxWidth = 960});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
