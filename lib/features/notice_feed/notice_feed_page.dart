import 'package:flutter/material.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/max_width_body.dart';
import '../../core/widgets/notification_bell_button.dart';
import '../../core/widgets/responsive_card_grid.dart';
import '../../core/widgets/titled_card.dart';

class _NoticeItem {
  const _NoticeItem({
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

class NoticeFeedPage extends StatefulWidget {
  const NoticeFeedPage({super.key});

  @override
  State<NoticeFeedPage> createState() => _NoticeFeedPageState();
}

class _NoticeFeedPageState extends State<NoticeFeedPage> {
  static const Color _brandColor = Color(0xFF346CB2);
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _metaColor = Color(0xFF64748B);
  static const Color _badgeColor = Color(0xFFE0E7FF);
  static const Color _badgeTextColor = Color(0xFF4F46E5);

  static const List<String> _tabs = ['전체', '학교', '학과', '장학', '맞춤'];

  static const String _subtitle = '학교·학과·장학 공지를 한곳에서 확인해요.';

  // TODO: 실제 사용자 이름/동기화 상태로 교체
  static const String _userFullName = '염가영';
  static const String _syncLabel = '동기화됨';

  // TODO: 실제 맞춤 수집처 목록으로 교체
  static const List<String> _customSources = [
    '학과공지',
    '장학공지',
    '대외활동',
    '동아리 게시판',
  ];

  // TODO: 실제 공지 데이터로 교체
  static const List<_NoticeItem> _notices = [
    _NoticeItem(
      tab: '학과',
      badgeLabel: '장학',
      title: '2026-1 소프트웨어융합공학과 장학금 신청 안내',
      meta: '학과공지 · 2026.06.02 · 마감 D-3',
    ),
    _NoticeItem(
      tab: '학교',
      badgeLabel: '비교과',
      title: '학습지원센터 비교과 프로그램 모집',
      meta: '학습지원센터 · 새 공지',
    ),
    _NoticeItem(
      tab: '학교',
      badgeLabel: '학사',
      title: '인하대학교 학사일정 변경 안내',
      meta: '학교공지 · 일정 추가 가능',
    ),
    _NoticeItem(
      tab: '맞춤',
      badgeLabel: '맞춤',
      title: '동아리 게시판 새 모집글 3개',
      meta: '맞춤 수집처 · 방금 전',
    ),
  ];

  String _selectedTab = _tabs[0];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotices = _notices.where((notice) {
      final matchesTab = _selectedTab == '전체' || notice.tab == _selectedTab;
      final matchesQuery = notice.title.contains(_searchQuery);
      return matchesTab && matchesQuery;
    }).toList();
    final screenSize = AppBreakpoints.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: MaxWidthBody(
          maxWidth: screenSize == ScreenSize.desktop ? 1200 : 960,
          child: screenSize == ScreenSize.desktop
              ? _buildDesktopBody(filteredNotices)
              : _buildMobileBody(filteredNotices),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: '공지 검색',
        hintStyle: const TextStyle(fontSize: 14, color: _metaColor),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _brandColor, width: 1.5),
        ),
      ),
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

  Widget _buildMobileBody(List<_NoticeItem> filteredNotices) {
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
                '공지 모아보기',
                style: AppTextStyles.heading1.copyWith(fontSize: 28),
              ),
              const NotificationBellButton(),
            ],
          ),
          const SizedBox(height: 4),
          const Text(_subtitle, style: TextStyle(fontSize: 14, color: _metaColor)),
          const SizedBox(height: 20),
          _buildSearchField(),
          const SizedBox(height: 16),
          _buildTabsRow(),
          const SizedBox(height: 16),
          if (filteredNotices.isEmpty)
            const Text(
              '표시할 공지가 없어요.',
              style: TextStyle(fontSize: 14, color: _metaColor),
            )
          else
            ResponsiveCardGrid(
              children: filteredNotices
                  .map((notice) => _NoticeCard(notice: notice))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopBody(List<_NoticeItem> filteredNotices) {
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
                    '공지 모아보기',
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
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchField(),
                      const SizedBox(height: 16),
                      _buildTabsRow(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: filteredNotices.isEmpty
                            ? const Text(
                                '표시할 공지가 없어요.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _metaColor,
                                ),
                              )
                            : SingleChildScrollView(
                                child: ResponsiveCardGrid(
                                  columnsOverride: 1,
                                  children: filteredNotices
                                      .map(
                                        (notice) => _NoticeCard(notice: notice),
                                      )
                                      .toList(),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: TitledCard(
                    title: '맞춤 수집처',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final source in _customSources)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(
                              source,
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

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});

  final _NoticeItem notice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _NoticeFeedPageState._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _NoticeFeedPageState._badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              notice.badgeLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _NoticeFeedPageState._badgeTextColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            notice.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            notice.meta,
            style: const TextStyle(
              fontSize: 13,
              color: _NoticeFeedPageState._metaColor,
            ),
          ),
        ],
      ),
    );
  }
}
