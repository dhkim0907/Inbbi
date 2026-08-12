import 'package:flutter/material.dart';

enum ScreenSize { mobile, desktop }

/// 반응형 레이아웃 기준점. 모바일/데스크톱 2단계만 사용한다.
class AppBreakpoints {
  AppBreakpoints._();

  /// Material 3 'expanded' window size class 기준.
  static const double desktop = 840;

  static ScreenSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static ScreenSize fromWidth(double width) =>
      width >= desktop ? ScreenSize.desktop : ScreenSize.mobile;
}
