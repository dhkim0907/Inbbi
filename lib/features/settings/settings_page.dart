import '../notification/realtime/realtime_scope.dart';
import '../notification/push/push_scope.dart';
import '../calendar/calendar_scope.dart';
import '../calendar/google_sign_in_button.dart' as google_button;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/base_view.dart';
import '../../core/widgets/notification_bell_button.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const Color _brandColor = Color(0xFF346CB2);
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _metaColor = Color(0xFF64748B);
  static const Color _linkedColor = Color(0xFF16A34A);

  static const String _subtitle = '포털·I-Class·캘린더 연동 상태와 알림을 관리해요.';

  // TODO: 로그인 연동 후 실제 사용자 정보로 교체
  static const String _userName = '염가영';
  static const String _userInitials = '가영';
  static const String _department = '소프트웨어융합공학과';
  static const int _semester = 5;

  // TODO: 실제 동기화 상태로 교체
  static const String _syncLabel = '동기화됨';

  bool _portalLinked = true;
  bool _iClassLinked = true;
  bool _dueDateAlertEnabled = true;

  Widget _buildStatusRow({
    required String label,
    required bool linked,
    required String onLabel,
    required String offLabel,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final title = Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              );
              final action =
                  trailing ??
                  Text(
                    linked ? onLabel : offLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: linked ? _linkedColor : _brandColor,
                    ),
                  );
              if (trailing != null && constraints.maxWidth < 440) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 12), action],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: title),
                  const SizedBox(width: 8),
                  action,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow({required String label, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: _metaColor),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleCalendarTap() async {
    final calendar = CalendarScope.of(context);
    if (calendar.googleAccount != null) {
      if (calendar.googleAuthorizationRequired) {
        await calendar.authorizeGoogle();
        return;
      }
      await calendar.disconnectGoogle();
      return;
    }
    if (!calendar.googleAuth.configured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google OAuth 클라이언트 설정이 필요해요.')),
      );
      return;
    }
    await calendar.connectGoogle();
  }

  Future<void> _handleAutoLoginReset() async {
    final calendar = CalendarScope.of(context);
    calendar.setAppToken(null);
    await calendar.disconnectGoogle();
    if (!mounted) return;
    final realtime = RealtimeScope.maybeOf(context);
    await realtime?.stop();
    if (!mounted) return;
    final push = PushScope.maybeOf(context);
    if (push != null && push.enabled) {
      if (push.busy) return;
      await push.setEnabled(false);
      if (!mounted) return;
      if (push.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림 연결을 해제하지 못했어요. 다시 시도해 주세요.')),
        );
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return BaseView(
      mobileBuilder: (context) => _buildMobileBody(),
      desktopBuilder: (context) => _buildDesktopBody(),
    );
  }

  Widget _buildMobileBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '마이 / 설정',
                style: AppTextStyles.heading1.copyWith(fontSize: 28),
              ),
              const NotificationBellButton(),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            _subtitle,
            style: TextStyle(fontSize: 14, color: _metaColor),
          ),
          const SizedBox(height: 20),
          ..._buildSettingsContent(),
        ],
      ),
    );
  }

  Widget _buildDesktopBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '마이 / 설정',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      _subtitle,
                      style: TextStyle(fontSize: 14, color: _metaColor),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const NotificationBellButton(),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _borderColor),
                      ),
                      child: const Text(
                        '$_userName · $_syncLabel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildSettingsContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSettingsContent() {
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _brandColor,
                shape: BoxShape.circle,
              ),
              child: const Text(
                _userInitials,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  _userName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_department · $_semester학기',
                  style: const TextStyle(fontSize: 13, color: _metaColor),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _buildStatusRow(
        label: '인하대 포털 연동 상태',
        linked: _portalLinked,
        onLabel: '연동됨',
        offLabel: '연동 안 됨',
        onTap: () => setState(() => _portalLinked = !_portalLinked),
      ),
      _buildStatusRow(
        label: 'I-Class 연동 상태',
        linked: _iClassLinked,
        onLabel: '연동됨',
        offLabel: '연동 안 됨',
        onTap: () => setState(() => _iClassLinked = !_iClassLinked),
      ),
      Builder(
        builder: (context) {
          final calendar = CalendarScope.of(context);
          return _buildStatusRow(
            label: 'Google Calendar 연동',
            linked: calendar.googleAccount != null,
            onLabel: calendar.googleAuthorizationRequired ? '권한 허용' : '연동됨',
            offLabel: 'Google 로그인',
            onTap:
                calendar.googleAccount != null &&
                    !calendar.googleAuthorizationRequired
                ? _handleGoogleCalendarTap
                : null,
            trailing: calendar.googleAccount == null
                ? kIsWeb &&
                          calendar.googleAuth.configured &&
                          calendar.googleReady
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: google_button.buildGoogleSignInButton(),
                        )
                      : TextButton(
                          onPressed: _handleGoogleCalendarTap,
                          child: const Text('Google 로그인'),
                        )
                : calendar.googleAuthorizationRequired
                ? TextButton(
                    onPressed: calendar.authorizeGoogle,
                    child: const Text('일정 권한 허용'),
                  )
                : null,
          );
        },
      ),
      _buildStatusRow(
        label: '과제 마감 알림 24시간 전',
        linked: _dueDateAlertEnabled,
        onLabel: '켜짐',
        offLabel: '꺼짐',
        onTap: () =>
            setState(() => _dueDateAlertEnabled = !_dueDateAlertEnabled),
      ),
      _buildActionRow(label: '자동 로그인 해제', onTap: _handleAutoLoginReset),
    ];
  }
}
