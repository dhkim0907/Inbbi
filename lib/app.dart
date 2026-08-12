import 'package:flutter/material.dart';
import 'core/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/main_tab_shell.dart';
import 'features/splash/splash_page.dart';
import 'features/auth/login_page.dart';

class InbbiApp extends StatelessWidget {
  const InbbiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '인삐',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => const SplashPage(),
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.home: (context) => const MainTabShell(initialIndex: 0),
        AppRoutes.calendar: (context) => const MainTabShell(initialIndex: 1),
        AppRoutes.noticeFeed: (context) => const MainTabShell(initialIndex: 2),
        AppRoutes.course: (context) => const MainTabShell(initialIndex: 3),
        AppRoutes.notification: (context) =>
            const MainTabShell(initialIndex: 5),
        AppRoutes.settings: (context) => const MainTabShell(initialIndex: 4),
      },
    );
  }
}
