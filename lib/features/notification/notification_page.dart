import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/base_view.dart';
import '../../core/widgets/notification_bell_button.dart';
import '../../core/widgets/responsive_card_grid.dart';
import '../../core/widgets/titled_card.dart';

class _AlertItem {
  const _AlertItem({
    required this.tab,
    required this.badgeLabel,
    required this.title,
    required this.meta,
  });

  final String tab;
  final String badgeLabel;
  final String title;
  final String meta;
}

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  static const Color _brandColor = Color(0xFF346CB2);
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _metaColor = Color(0xFF64748B);
  static const Color _badgeColor = Color(0xFFE0E7FF);
  static const Color _badgeTextColor = Color(0xFF4F46E5);

  static const List<String> _tabs = ['전체', '마감', '강의', '맞춤'];

  static const String _subtitle = '마감·강의·맞춤 공지 알림을 관리해요.';

  // TODO: 실제 사용자 이름/동기화 상태로 교체
  static const String _userFullName = '염가영';
  static const String _syncLabel = '동기화됨';

  // TODO: 실제 알림 설정 상태로 교체
  static const List<String> _notificationSettings = [
    '과제 24시간 전 켜짐',
    '강의 미수강 켜짐',
    '맞춤 공지 켜짐',
  ];

  // TODO: 실제 알림 데이터로 교체
  static const List<_AlertItem> _alerts = [
    _AlertItem(
      tab: '마감',
      badgeLabel: '마감',
      title: '마감 24시간 전',
      meta: '[소프트웨어공학] 요구사항 명세서 제출이 내일 23:59 마감돼요.',
    ),
    _AlertItem(
      tab: '강의',
      badgeLabel: '강의',
      title: '미수강 알림',
      meta: '[I-Class] 인터넷 프로그래밍 9주차 강의를 아직 수강하지 않았어요.',
    ),
    _AlertItem(
      tab: '맞춤',
      badgeLabel: '맞춤',
      title: '맞춤 공지 업데이트',
      meta: '[대외활동 게시판] 새 공고 3개가 등록됐어요.',
    ),
    _AlertItem(
      tab: '맞춤',
      badgeLabel: '연동',
      title: '구글 캘린더 동기화',
      meta: '이번 주 학사 일정 4개를 캘린더에 추가했어요.',
    ),
  ];

  String _selectedTab = _tabs[0];

  @override
  Widget build(BuildContext context) {
    final filteredAlerts = _alerts
        .where((alert) => _selectedTab == '전체' || alert.tab == _selectedTab)
        .toList();

    return BaseView(
      mobileBuilder: (context) => _buildMobileBody(filteredAlerts),
      desktopBuilder: (context) => _buildDesktopBody(filteredAlerts),
    );
  }

  Widget _buildTabsRow() {
    return Row(
      children: _tabs.map((tab) {
        final bool selected = tab == _selectedTab;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _selectedTab = tab),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? _brandColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: selected ? null : Border.all(color: _borderColor),
              ),
              child: Text(
                tab,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileBody(List<_AlertItem> filteredAlerts) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('알림', style: AppTextStyles.heading1.copyWith(fontSize: 28)),
              const NotificationBellButton(),
            ],
          ),
          const SizedBox(height: 4),
          const Text(_subtitle, style: TextStyle(fontSize: 14, color: _metaColor)),
          const SizedBox(height: 20),
          _buildTabsRow(),
          const SizedBox(height: 16),
          if (filteredAlerts.isEmpty)
            const Text(
              '표시할 알림이 없어요.',
              style: TextStyle(fontSize: 14, color: _metaColor),
            )
          else
            ResponsiveCardGrid(
              children: filteredAlerts
                  .map((alert) => _AlertCard(alert: alert))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopBody(List<_AlertItem> filteredAlerts) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 32),
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
                    '알림',
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
                      '$_userFullName · $_syncLabel',
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
          _buildTabsRow(),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: filteredAlerts.isEmpty
                      ? const Text(
                          '표시할 알림이 없어요.',
                          style: TextStyle(fontSize: 14, color: _metaColor),
                        )
                      : SingleChildScrollView(
                          child: ResponsiveCardGrid(
                            columnsOverride: 1,
                            children: filteredAlerts
                                .map((alert) => _AlertCard(alert: alert))
                                .toList(),
                          ),
                        ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: TitledCard(
                    title: '알림 설정',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final setting in _notificationSettings)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(
                              setting,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final _AlertItem alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _NotificationPageState._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _NotificationPageState._badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              alert.badgeLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _NotificationPageState._badgeTextColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            alert.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            alert.meta,
            style: const TextStyle(
              fontSize: 13,
              color: _NotificationPageState._metaColor,
            ),
          ),
        ],
      ),
    );
  }
}
