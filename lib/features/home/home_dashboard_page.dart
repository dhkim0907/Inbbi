import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/base_view.dart';
import '../../core/widgets/month_calendar_grid.dart';
import '../../core/widgets/notification_bell_button.dart';
import '../../core/widgets/responsive_card_grid.dart';
import '../../core/widgets/titled_card.dart';
import '../calendar/calendar_scope.dart';

class _HomeTaskItem {
  const _HomeTaskItem({
    required this.category,
    required this.title,
    required this.meta,
    required this.badgeColor,
    required this.badgeTextColor,
  });

  final String category;
  final String title;
  final String meta;
  final Color badgeColor;
  final Color badgeTextColor;
}

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  static const Color _brandColor = Color(0xFF346CB2);
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _metaColor = Color(0xFF64748B);

  // TODO: 로그인 연동 후 실제 사용자 이름으로 교체
  static const String _userName = '가영';
  static const String _userFullName = '염가영';

  // TODO: 실제 오늘 마감 과제 수로 교체
  static const int _todayDueCount = 2;

  // TODO: 실제 미수강 강의 수로 교체
  static const int _notEnrolledCount = 1;

  // TODO: 실제 오늘 할일 수로 교체
  static const int _todoCount = 4;

  // TODO: 실제 이번 주 진행률로 교체
  static const double _weeklyProgress = 0.68;

  static const List<String> _tabs = ['전체', '과제', '강의', '공지'];

  // TODO: 실제 할일/공지 데이터로 교체
  static const List<_HomeTaskItem> _items = [
    _HomeTaskItem(
      category: '과제',
      title: 'SW융합 프로젝트 중간보고서',
      meta: '오늘 23:59 마감 · D-Day',
      badgeColor: Color(0xFFFEF3C7),
      badgeTextColor: Color(0xFFD97706),
    ),
    _HomeTaskItem(
      category: '강의',
      title: '인터넷프로그래밍 9주차 강의',
      meta: '수강률 0% · 6시간 남음',
      badgeColor: Color(0xFFDBEAFE),
      badgeTextColor: Color(0xFF2563EB),
    ),
    _HomeTaskItem(
      category: '공지',
      title: '장학금 신청 안내 확인',
      meta: '학과공지 · D-3',
      badgeColor: Color(0xFFDCFCE7),
      badgeTextColor: Color(0xFF16A34A),
    ),
  ];

  String _selectedTab = _tabs[0];

  @override
  Widget build(BuildContext context) {
    return BaseView(
      mobileBuilder: (context) => _buildMobileBody(),
      desktopBuilder: (context) => _buildDesktopBody(),
    );
  }

  Widget _buildMobileBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '안녕하세요, $_userName님',
                style: AppTextStyles.heading1.copyWith(fontSize: 24),
              ),
              const NotificationBellButton(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '오늘 마감 $_todayDueCount개 · 미수강 $_notEnrolledCount개',
            style: const TextStyle(fontSize: 14, color: _metaColor),
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _brandColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '오늘 해야 할 일',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      '$_todoCount개',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 25),
                    const Expanded(
                      child: Text(
                        '마감 임박 항목부터 자동 정렬했어요.',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: _tabs.map((tab) {
              final bool selected = tab == _selectedTab;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _selectedTab = tab),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
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
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: ResponsiveCardGrid(
                children: _items
                    .where(
                      (item) =>
                          _selectedTab == '전체' || item.category == _selectedTab,
                    )
                    .map((item) => _HomeTaskCard(item: item))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '이번 주 진행률',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${(_weeklyProgress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _brandColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _weeklyProgress,
                    minHeight: 8,
                    backgroundColor: _borderColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _brandColor,
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

  Widget _buildDesktopBody() {
    final calendar = CalendarScope.of(context);
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
                    '오늘의 대시보드',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '마감 임박 항목부터 자동 정렬했어요.',
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
                    child: Text(
                      '$_userFullName · ${calendar.appLoaded && calendar.appError == null ? '일정 조회됨' : '일정 확인 필요'}',
                      style: const TextStyle(
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
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: '오늘 해야 할 일',
                  value: '$_todoCount개',
                  valueColor: _brandColor,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _StatCard(
                  label: '이번 주 진행률',
                  value: '${(_weeklyProgress * 100).round()}%',
                  valueColor: const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _StatCard(
                  label: '동기화 상태',
                  value: calendar.appLoading
                      ? '조회 중'
                      : calendar.appLoaded && calendar.appError == null
                      ? '정상'
                      : '확인 필요',
                  valueColor: const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TitledCard(
                    title: '우선순위 To-Do',
                    child: SingleChildScrollView(
                      child: ResponsiveCardGrid(
                        columnsOverride: 1,
                        children: _items
                            .map((item) => _HomeTaskCard(item: item))
                            .toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: TitledCard(
                    title: '${calendar.month.month}월 캘린더',
                    child: SingleChildScrollView(
                      child: MonthCalendarGrid(
                        month: calendar.month,
                        eventDays: calendar.eventDays,
                      ),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _HomeDashboardPageState._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTaskCard extends StatelessWidget {
  const _HomeTaskCard({required this.item});

  final _HomeTaskItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _HomeDashboardPageState._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            decoration: BoxDecoration(
              color: item.badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.category,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: item.badgeTextColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.meta,
            style: const TextStyle(
              fontSize: 13,
              color: _HomeDashboardPageState._metaColor,
            ),
          ),
        ],
      ),
    );
  }
}
