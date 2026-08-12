import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/base_view.dart';
import '../../core/widgets/notification_bell_button.dart';
import '../../core/widgets/responsive_card_grid.dart';
import '../../core/widgets/titled_card.dart';

class _CourseItem {
  const _CourseItem({
    required this.tab,
    required this.title,
    required this.meta,
    required this.progress,
  });

  final String tab;
  final String title;
  final String meta;
  final double progress;
}

class CourseManagementPage extends StatefulWidget {
  const CourseManagementPage({super.key});

  @override
  State<CourseManagementPage> createState() => _CourseManagementPageState();
}

class _CourseManagementPageState extends State<CourseManagementPage> {
  static const Color _brandColor = Color(0xFF346CB2);
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _metaColor = Color(0xFF64748B);

  static const List<String> _tabs = ['전체', '미수강', '과제', '완료'];

  static const String _subtitle = 'I-Class 수강 현황과 과제를 한눈에 확인해요.';

  // TODO: 실제 사용자 이름/동기화 상태로 교체
  static const String _userFullName = '염가영';
  static const String _syncLabel = '동기화됨';

  // TODO: 실제 오늘 액션 데이터로 교체
  static const List<String> _todayActions = [
    '미수강 강의 1개',
    '오늘 마감 과제 1개',
    '제출 확인 필요 2개',
  ];

  // TODO: 실제 강의 데이터로 교체
  static const List<_CourseItem> _courses = [
    _CourseItem(
      tab: '미수강',
      title: '인터넷프로그래밍',
      meta: '9주차 강의 미수강 · 과제 1개',
      progress: 0.37,
    ),
    _CourseItem(
      tab: '과제',
      title: '소프트웨어융합 프로젝트',
      meta: '최종 발표 준비 · 오늘 마감',
      progress: 0.68,
    ),
    _CourseItem(
      tab: '과제',
      title: '객체지향프로그래밍',
      meta: '과제 4 미제출 · 내일 마감',
      progress: 0.80,
    ),
  ];

  String _selectedTab = _tabs[0];

  @override
  Widget build(BuildContext context) {
    final filteredCourses = _courses
        .where((course) => _selectedTab == '전체' || course.tab == _selectedTab)
        .toList();

    return BaseView(
      mobileBuilder: (context) => _buildMobileBody(filteredCourses),
      desktopBuilder: (context) => _buildDesktopBody(filteredCourses),
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

  Widget _buildMobileBody(List<_CourseItem> filteredCourses) {
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
                '강의 관리',
                style: AppTextStyles.heading1.copyWith(fontSize: 28),
              ),
              const NotificationBellButton(),
            ],
          ),
          const SizedBox(height: 4),
          const Text(_subtitle, style: TextStyle(fontSize: 14, color: _metaColor)),
          const SizedBox(height: 20),
          _buildTabsRow(),
          const SizedBox(height: 20),
          if (filteredCourses.isEmpty)
            const Text(
              '표시할 강의가 없어요.',
              style: TextStyle(fontSize: 14, color: _metaColor),
            )
          else
            ResponsiveCardGrid(
              children: filteredCourses
                  .map((course) => _CourseCard(course: course))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopBody(List<_CourseItem> filteredCourses) {
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
                    '강의 관리',
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
                  child: filteredCourses.isEmpty
                      ? const Text(
                          '표시할 강의가 없어요.',
                          style: TextStyle(fontSize: 14, color: _metaColor),
                        )
                      : SingleChildScrollView(
                          child: ResponsiveCardGrid(
                            columnsOverride: 1,
                            children: filteredCourses
                                .map((course) => _CourseCard(course: course))
                                .toList(),
                          ),
                        ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: TitledCard(
                    title: '오늘 액션',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final action in _todayActions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(
                              action,
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

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final _CourseItem course;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _CourseManagementPageState._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            course.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            course.meta,
            style: const TextStyle(
              fontSize: 14,
              color: _CourseManagementPageState._metaColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: course.progress,
                    minHeight: 8,
                    backgroundColor: _CourseManagementPageState._borderColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _CourseManagementPageState._brandColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${(course.progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _CourseManagementPageState._brandColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
