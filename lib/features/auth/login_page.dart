import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../calendar/calendar_scope.dart';
import '../notification/realtime/realtime_scope.dart';
import 'auth_scope.dart';
import 'test_auth_api.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color _brandColor = Color(0xFF346CB2);
  static const Color _desktopBackgroundColor = Color(0xFFEEF2FA);

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hintText) {
    final borderRadius = BorderRadius.circular(20);
    const borderColor = Color(0xFFC7D0E0);
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: _brandColor, width: 1.5),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthScope.of(
        context,
      ).login(_idController.text.trim(), _passwordController.text);
      if (!mounted) return;
      CalendarScope.of(context).setAppToken(token);
      final realtime = RealtimeScope.maybeOf(context);
      if (realtime != null && token != null) {
        await realtime.start(accessToken: token, deviceId: 'test-device');
      }
      if (mounted) Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '로그인 서버에 연결하지 못했어요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = AppBreakpoints.of(context);
    final form = _buildForm();

    if (screenSize == ScreenSize.mobile) {
      return Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 64),
                form,
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _desktopBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: form,
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '인삐',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: _brandColor,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'I-Class와 학사 정보를\n한 번에 관리하세요.',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          '계정 ID',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _idController,
          keyboardType: TextInputType.text,
          style: const TextStyle(fontSize: 16, color: Colors.black),
          decoration: _fieldDecoration(''),
        ),
        const SizedBox(height: 24),
        const Text(
          '비밀번호',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(fontSize: 16, color: Colors.black),
          decoration: _fieldDecoration(''),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _loading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    '로그인',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            '비밀번호는 암호화되어 저장됩니다. ',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
