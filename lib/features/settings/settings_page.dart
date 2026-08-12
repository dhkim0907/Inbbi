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
  bool _googleCalendarLinked = false;
  bool _dueDateAlertEnabled = true;

  Widget _buildStatusRow({
    required String label,
    required bool linked,
    required String onLabel,
    required String offLabel,
    required VoidCallback onTap,
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
              Text(
                linked ? onLabel : offLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: linked ? _linkedColor : _brandColor,
                ),
              ),
            ],
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

  void _handleAutoLoginReset() {
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
          const Text(_subtitle, style: TextStyle(fontSize: 14, color: _metaColor)),
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
                    Text(_subtitle, style: TextStyle(fontSize: 14, color: _metaColor)),
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
      _buildStatusRow(
        label: 'Google Calendar 연동',
        linked: _googleCalendarLinked,
        onLabel: '연동됨',
        offLabel: '연동하기',
        onTap: () =>
            setState(() => _googleCalendarLinked = !_googleCalendarLinked),
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
