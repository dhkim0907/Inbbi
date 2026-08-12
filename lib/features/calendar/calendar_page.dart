import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/base_view.dart';
import '../../core/widgets/month_calendar_grid.dart';
import '../../core/widgets/notification_bell_button.dart';
import '../../core/widgets/responsive_card_grid.dart';

class _CalendarEvent {
  const _CalendarEvent({
    required this.day,
    required this.category,
    required this.badgeLabel,
    required this.title,
    required this.meta,
  });

  final int day;
  final String category;
  final String badgeLabel;
  final String title;
  final String meta;
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const Color _brandColor = Color(0xFF346CB2);
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _metaColor = Color(0xFF64748B);
  static const Color _badgeColor = Color(0xFFE0E7FF);
  static const Color _badgeTextColor = Color(0xFF4F46E5);

  static const List<String> _weekdayShortNames = [
    '월',
    '화',
    '수',
    '목',
    '금',
    '토',
    '일',
  ];

  static const List<String> _weekdayFullNames = [
    '월요일',
    '화요일',
    '수요일',
    '목요일',
    '금요일',
    '토요일',
    '일요일',
  ];

  static const List<String> _tabs = ['전체', '과제', '강의', '공지'];

  static const String _subtitle = '학사 일정과 마감일을 월간/일간으로 확인해요.';

  // TODO: 실제 사용자 이름/동기화 상태로 교체
  static const String _userFullName = '염가영';
  static const String _syncLabel = '동기화됨';

  // TODO: 실제 월 정보로 교체
  DateTime _month = DateTime(2026, 6, 1);

  // TODO: 실제 일정 데이터로 교체
  static const List<_CalendarEvent> _events = [
    _CalendarEvent(
      day: 3,
      category: '강의',
      badgeLabel: '강의',
      title: '10:00 자료구조 특강',
      meta: '강의 · 온라인',
    ),
    _CalendarEvent(
      day: 8,
      category: '과제',
      badgeLabel: 'D-5',
      title: '18:00 캡스톤 설계안 제출',
      meta: '과제 · 미제출',
    ),
    _CalendarEvent(
      day: 13,
      category: '과제',
      badgeLabel: 'D-0',
      title: '23:59 SW융합 프로젝트 발표 준비',
      meta: '과제 · 마감 임박',
    ),
    _CalendarEvent(
      day: 13,
      category: '공지',
      badgeLabel: '공지',
      title: '18:00 학과 공지 확인',
      meta: '공지 · 저장됨',
    ),
    _CalendarEvent(
      day: 18,
      category: '강의',
      badgeLabel: '강의',
      title: '14:00 인터넷프로그래밍 실습',
      meta: '강의 · 대면',
    ),
    _CalendarEvent(
      day: 26,
      category: '과제',
      badgeLabel: 'D-1',
      title: '23:59 알고리즘 과제 제출',
      meta: '과제 · 마감 임박',
    ),
  ];

  String _selectedTab = _tabs[0];
  int _selectedDay = 13;

  int _daysInMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 0).day;

  Set<int> get _eventDays => _events.map((event) => event.day).toSet();

  Future<void> _openMonthPicker() async {
    final DateTime? result = await showDialog<DateTime>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 320,
          child: _MonthYearPickerSheet(
            initialMonth: _month,
            brandColor: _brandColor,
            borderColor: _borderColor,
          ),
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _month = result;
      _selectedDay = _selectedDay.clamp(1, _daysInMonth(result));
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = DateTime(_month.year, _month.month, _selectedDay);
    final selectedWeekdayName = _weekdayFullNames[selectedDate.weekday - 1];
    final dayEvents = _events
        .where(
          (event) =>
              event.day == _selectedDay &&
              (_selectedTab == '전체' || event.category == _selectedTab),
        )
        .toList();

    return BaseView(
      mobileBuilder: (context) =>
          _buildMobileBody(dayEvents, selectedWeekdayName),
      desktopBuilder: (context) =>
          _buildDesktopBody(dayEvents, selectedWeekdayName),
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

  Widget _buildMobileBody(
    List<_CalendarEvent> dayEvents,
    String selectedWeekdayName,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('캘린더', style: AppTextStyles.heading1.copyWith(fontSize: 28)),
              const NotificationBellButton(),
            ],
          ),
          const SizedBox(height: 4),
          const Text(_subtitle, style: TextStyle(fontSize: 14, color: _metaColor)),
          const SizedBox(height: 20),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _openMonthPicker,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_month.year}년 ${_month.month}월',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildTabsRow(),
          const SizedBox(height: 16),
          _buildMobileMonthGrid(),
          const SizedBox(height: 20),
          Text(
            '${_month.month}월 $_selectedDay일 $selectedWeekdayName',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (dayEvents.isEmpty)
            const Text(
              '일정이 없어요.',
              style: TextStyle(fontSize: 14, color: _metaColor),
            )
          else
            ResponsiveCardGrid(
              children: dayEvents
                  .map((event) => _CalendarEventCard(event: event))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileMonthGrid() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: _weekdayShortNames
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _metaColor,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          MonthCalendarGrid(
            month: _month,
            eventDays: _eventDays,
            selectedDay: _selectedDay,
            onDaySelected: (day) => setState(() => _selectedDay = day),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBody(
    List<_CalendarEvent> dayEvents,
    String selectedWeekdayName,
  ) {
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
                    '캘린더',
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
                Expanded(flex: 3, child: _buildDesktopMonthGrid()),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: _buildEventListPanel(dayEvents, selectedWeekdayName),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopMonthGrid() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _openMonthPicker,
            child: Text(
              '${_month.year}년 ${_month.month}월',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: _weekdayShortNames
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _metaColor,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          MonthCalendarGrid(
            month: _month,
            eventDays: _eventDays,
            selectedDay: _selectedDay,
            onDaySelected: (day) => setState(() => _selectedDay = day),
          ),
        ],
      ),
    );
  }

  Widget _buildEventListPanel(
    List<_CalendarEvent> dayEvents,
    String selectedWeekdayName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_month.month}월 $_selectedDay일 $selectedWeekdayName',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: dayEvents.isEmpty
              ? const Text(
                  '일정이 없어요.',
                  style: TextStyle(fontSize: 14, color: _metaColor),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final event in dayEvents)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CalendarEventCard(event: event),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _CalendarEventCard extends StatelessWidget {
  const _CalendarEventCard({required this.event});

  static const Color _dueSoonColor = Color(0xFFDC2626);

  final _CalendarEvent event;

  int? get _daysRemaining {
    final String label = event.badgeLabel;
    if (!label.startsWith('D-')) return null;
    return int.tryParse(label.substring(2));
  }

  @override
  Widget build(BuildContext context) {
    final int? daysRemaining = _daysRemaining;
    final bool isDDay = daysRemaining != null;
    final bool isDueSoon = daysRemaining != null && daysRemaining <= 3;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _CalendarPageState._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDueSoon
                  ? _dueSoonColor
                  : isDDay
                      ? _CalendarPageState._brandColor
                      : _CalendarPageState._badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              event.badgeLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isDueSoon ? FontWeight.bold : FontWeight.w600,
                color: isDDay
                    ? Colors.white
                    : _CalendarPageState._badgeTextColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            event.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            event.meta,
            style: const TextStyle(
              fontSize: 13,
              color: _CalendarPageState._metaColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthYearPickerSheet extends StatefulWidget {
  const _MonthYearPickerSheet({
    required this.initialMonth,
    required this.brandColor,
    required this.borderColor,
  });

  final DateTime initialMonth;
  final Color brandColor;
  final Color borderColor;

  @override
  State<_MonthYearPickerSheet> createState() => _MonthYearPickerSheetState();
}

class _MonthYearPickerSheetState extends State<_MonthYearPickerSheet> {
  late int _year = widget.initialMonth.year;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '$_year년',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: List.generate(12, (index) {
                final int month = index + 1;
                final bool selected =
                    _year == widget.initialMonth.year &&
                    month == widget.initialMonth.month;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      Navigator.of(context).pop(DateTime(_year, month, 1)),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? widget.brandColor : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? null
                          : Border.all(color: widget.borderColor),
                    ),
                    child: Text(
                      '$month월',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
