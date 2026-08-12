import 'package:flutter/material.dart';
import '../layout/app_breakpoints.dart';

/// 세로로 쌓인 전체 너비 카드 목록을 데스크톱에서 다단 레이아웃으로 바꾼다.
/// 카드 높이가 서로 달라 [GridView]의 고정 aspect ratio 대신 [Wrap] +
/// 고정 너비 [SizedBox]로 배치한다.
class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    super.key,
    required this.children,
    this.columnsOverride,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  final List<Widget> children;

  /// 화면 전체가 아니라 일부 슬롯(예: 캘린더 데스크톱 좌우 배치) 안에서
  /// 쓰일 때 breakpoint 기반 열 수를 무시하고 강제 지정하기 위한 탈출구.
  final int? columnsOverride;
  final double spacing;
  final double runSpacing;

  static int _columnsFor(ScreenSize size) => switch (size) {
    ScreenSize.mobile => 1,
    ScreenSize.desktop => 3,
  };

  @override
  Widget build(BuildContext context) {
    final columns = columnsOverride ?? _columnsFor(AppBreakpoints.of(context));

    if (columns <= 1) {
      return Column(
        children: [
          for (final child in children)
            Padding(
              padding: EdgeInsets.only(bottom: runSpacing),
              child: child,
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: columnWidth, child: child),
          ],
        );
      },
    );
  }
}
