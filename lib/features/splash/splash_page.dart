import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import '../../core/theme/app_colors.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const Color _brandColor = Color(0xFF346CB2);
  static const Duration _dotInterval = Duration(milliseconds: 250);
  static const int _maxCycles = 2;
  static const TextStyle _loadingTextStyle = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  Timer? _timer;
  int _dotCount = 0;
  int _cycleCount = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_dotInterval, _onTick);
  }

  void _onTick(Timer timer) {
    setState(() {
      _dotCount = (_dotCount + 1) % 4;
    });
    if (_dotCount == 0) {
      _cycleCount++;
      if (_cycleCount >= _maxCycles) {
        timer.cancel();
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    }
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
