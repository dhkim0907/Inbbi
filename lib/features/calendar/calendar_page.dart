import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/base_view.dart';
import '../../core/widgets/month_calendar_grid.dart';
import '../../core/widgets/notification_bell_button.dart';
import 'calendar_controller.dart';
import 'calendar_event.dart';
import 'calendar_scope.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];
  static const _categories = ['전체', '과제', '강의', '공지', '기타', 'Google'];
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = '전체';

  Future<void> _pickMonth(CalendarController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '표시할 월 선택',
    );
    if (picked == null || !mounted) return;
    final maxDay = DateTime(picked.year, picked.month + 1, 0).day;
    setState(
      () => _selectedDate = DateTime(
        picked.year,
        picked.month,
        _selectedDate.day.clamp(1, maxDay),
      ),
    );
    await controller.setMonth(picked);
  }

  @override
  Widget build(BuildContext context) {
    final controller = CalendarScope.of(context);
    final month = controller.month;
    if (_selectedDate.year != month.year ||
        _selectedDate.month != month.month) {
      _selectedDate = DateTime(month.year, month.month, 1);
    }
    final dayEvents = controller.events
        .where(
          (event) =>
              event.occursOn(_selectedDate) &&
              (_selectedCategory == '전체' ||
                  event.category == _selectedCategory),
        )
        .toList();
    return BaseView(
      mobileBuilder: (_) => _mobile(controller, dayEvents),
      desktopBuilder: (_) => _desktop(controller, dayEvents),
    );
  }

  Widget _header() => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('캘린더', style: AppTextStyles.heading1.copyWith(fontSize: 28)),
            const SizedBox(height: 4),
            const Text(
              '서버 일정과 연결한 Google 일정을 확인해요.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      const NotificationBellButton(),
    ],
  );

  Widget _toolbar(CalendarController controller) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          TextButton.icon(
            onPressed: () => _pickMonth(controller),
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text('${controller.month.year}년 ${controller.month.month}월'),
          ),
          const Spacer(),
          IconButton(
            tooltip: '일정 새로고침',
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final category in _categories)
            ChoiceChip(
              label: Text(category),
              selected: _selectedCategory == category,
              onSelected: (_) => setState(() => _selectedCategory = category),
            ),
        ],
      ),
      if (controller.appLoading || controller.googleLoading)
        const LinearProgressIndicator(),
      if (controller.googleAuthorizationRequired)
        TextButton(
          onPressed: controller.authorizeGoogle,
          child: const Text('Google 일정 조회 권한 허용'),
        ),
      if (controller.googleAccount != null &&
          controller.googleLoaded &&
          controller.googleReceivedCount == 0)
        const Text('이 달의 Google 기본 캘린더에 일정이 없어요.'),
    ],
  );

  Widget _grid(CalendarController controller) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            for (final name in _weekdayNames)
              Expanded(child: Center(child: Text(name))),
          ],
        ),
        const SizedBox(height: 8),
        MonthCalendarGrid(
          month: controller.month,
          eventDays: controller.eventDays,
          selectedDay: _selectedDate.day,
          onDaySelected: (day) => setState(
            () => _selectedDate = DateTime(
              controller.month.year,
              controller.month.month,
              day,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _dayList(List<CalendarEvent> dayEvents) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${_selectedDate.month}월 ${_selectedDate.day}일 ${_weekdayNames[_selectedDate.weekday - 1]}요일',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      if (dayEvents.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '표시할 일정이 없어요.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        )
      else
        for (final event in dayEvents)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CalendarEventCard(event: event),
          ),
    ],
  );

  Widget _mobile(CalendarController controller, List<CalendarEvent> events) =>
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 20),
            _toolbar(controller),
            const SizedBox(height: 16),
            _grid(controller),
            const SizedBox(height: 20),
            _dayList(events),
          ],
        ),
      );

  Widget _desktop(CalendarController controller, List<CalendarEvent> events) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(40, 32, 40, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 24),
            _toolbar(controller),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _grid(controller)),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(child: _dayList(events)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CalendarEventCard extends StatelessWidget {
  const _CalendarEventCard({required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final time = event.start.toLocal();
    final timeLabel = event.allDay
        ? '종일'
        : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      child: ListTile(
        title: Text(event.title),
        subtitle: Text(
          '$timeLabel · ${event.category} · ${event.source == CalendarSource.google ? 'Google 읽기 전용' : '앱 서버'}',
        ),
      ),
    );
  }
}
