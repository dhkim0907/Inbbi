import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_scope.dart';
import '../calendar/calendar_scope.dart';
import '../notification/realtime/realtime_scope.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const Color _brandColor = Color(0xFF346CB2);
  static const Duration _dotInterval = Duration(milliseconds: 250);
  static const TextStyle _loadingTextStyle = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  Timer? _timer;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_dotInterval, _onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreLogin());
    });
  }

  Future<void> _restoreLogin() async {
    String? token;
    try {
      token = await AuthScope.of(context).restore();
      if (token != null && mounted) {
        CalendarScope.of(context).setAppToken(token);
        await RealtimeScope.maybeOf(
          context,
        )?.start(accessToken: token, deviceId: 'test-device');
      }
    } catch (_) {
      token = null;
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacementNamed(token == null ? AppRoutes.login : AppRoutes.home);
  }

  void _onTick(Timer timer) {
    setState(() {
      _dotCount = (_dotCount + 1) % 4;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '인삐',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: _brandColor,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '오늘의 학사·학습 비서',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: 64,
              height: 4,
              decoration: BoxDecoration(
                color: _brandColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('내 일정을 불러오는 중', style: _loadingTextStyle),
                SizedBox(
                  width: 18,
                  child: Text('.' * _dotCount, style: _loadingTextStyle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
