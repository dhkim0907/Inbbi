import 'package:flutter/material.dart';
import '../layout/app_breakpoints.dart';
import '../theme/app_colors.dart';
import 'max_width_body.dart';

/// 탭 페이지들이 공유하는 화면 골격.
/// `Scaffold` + `SafeArea` + [MaxWidthBody] + 모바일/데스크톱 분기를 한 곳에서
/// 처리하고, 각 페이지는 [mobileBuilder]/[desktopBuilder]로 콘텐츠만 넘긴다.
/// 화면 크기와 무관하게 동일한 콘텐츠를 쓰는 페이지(예: 설정)는 같은 빌더를
/// 양쪽에 넘기면 된다.
class BaseView extends StatelessWidget {
  const BaseView({
    super.key,
    required this.mobileBuilder,
    required this.desktopBuilder,
    this.maxWidth,
    this.backgroundColor = AppColors.background,
    this.floatingActionButton,
  });

  final WidgetBuilder mobileBuilder;
  final WidgetBuilder desktopBuilder;

  /// 지정하지 않으면 화면 크기에 따라 [_mobileMaxWidth]/[_desktopMaxWidth]를 쓴다.
  final double? maxWidth;
  final Color backgroundColor;
  final Widget? floatingActionButton;

  static const double _mobileMaxWidth = 960;
  static const double _desktopMaxWidth = 1200;

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.of(context) == ScreenSize.desktop;

    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: MaxWidthBody(
          maxWidth:
              maxWidth ?? (isDesktop ? _desktopMaxWidth : _mobileMaxWidth),
          child: isDesktop ? desktopBuilder(context) : mobileBuilder(context),
        ),
      ),
    );
  }
}
