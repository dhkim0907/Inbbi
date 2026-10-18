import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/base_view.dart';
import '../../core/layout/app_breakpoints.dart';
import 'calendar_design.dart';
import '../../core/widgets/calendar_week_event_bars.dart';
import '../../core/widgets/notification_bell_button.dart';
import 'calendar_controller.dart';
import 'calendar_event.dart';
import 'calendar_event_details_dialog.dart';
import 'calendar_event_presentation.dart';
import 'calendar_scope.dart';
import 'calendar_event_dialog.dart';
import 'calendar_event_draft.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, this.initialDate});
  final DateTime? initialDate;
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];
  static const _categories = ['강의', '과제', '일정', '할일'];

  String _categoryOf(CalendarEvent event) =>
      _categories.contains(event.category) ? event.category : '일정';
  late DateTime _selectedDate = widget.initialDate ?? DateTime.now();
  final Set<String> _selectedCategories = {..._categories};
  bool _addingEvent = false;

  Future<void> _addEvent(CalendarController controller) async {
    if (_addingEvent) return;
    _addingEvent = true;
    try {
      final draft = await showDialog<CalendarEventDraft>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CalendarEventDialog(
          initialDate: _selectedDate,
          onSave: (draft) async {
            await controller.createEvent(draft);
          },
        ),
      );
      if (draft == null || !mounted) return;
      _selectDate(controller, draft.start);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정을 저장했어요.')));
    } finally {
      _addingEvent = false;
    }
  }

  Future<void> _showEventDetails(CalendarEvent event) => showDialog<void>(
    context: context,
    builder: (_) => CalendarEventDetailsDialog(
      event: event,
      onEdit: (current) async {
        CalendarEvent? updated;
        final controller = CalendarScope.of(context);
        final draft = await showDialog<CalendarEventDraft>(
          context: context,
          barrierDismissible: false,
          builder: (_) => CalendarEventDialog(
            initialDate: current.start,
            initialEvent: current,
            onSave: (draft) async {
              updated = await controller.updateEvent(current, draft);
            },
          ),
        );
        if (draft == null || !mounted) return null;
        _selectDate(controller, updated!.start);
        return updated;
      },
      onDelete: (current) => CalendarScope.of(context).deleteEvent(current),
    ),
  );

  void _selectDate(CalendarController controller, DateTime date) {
    setState(() => _selectedDate = date);
    if (date.year != controller.month.year ||
        date.month != controller.month.month) {
      controller.setMonth(date);
    }
  }

  Future<void> _pickMonth(CalendarController controller) async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPickerDialog(initialMonth: controller.month),
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
              (_selectedCategories.length == _categories.length ||
                  _selectedCategories.contains(_categoryOf(event))),
        )
        .toList();
    return BaseView(
      backgroundColor: CalendarDesign.background,
      floatingActionButton: SizedBox(
        width: AppBreakpoints.of(context) == ScreenSize.mobile ? 52 : 57,
        height: AppBreakpoints.of(context) == ScreenSize.mobile ? 52 : 57,
        child: FloatingActionButton(
          heroTag: 'calendar-add-event',
          tooltip: '일정 추가',
          backgroundColor: CalendarDesign.brand,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          elevation: 6,
          onPressed: () => _addEvent(controller),
          child: const CalendarDesignIcon('add'),
        ),
      ),
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
            Text(
              '캘린더',
              style: AppTextStyles.heading1.copyWith(
                fontSize: 27,
                color: CalendarDesign.text,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '강의부터 나의 일정까지, 하루를 한눈에 확인해요.',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: CalendarDesign.muted,
              ),
            ),
          ],
        ),
      ),
      const NotificationBellButton(
        backgroundColor: CalendarDesign.brand,
        icon: CalendarDesignIcon('bell'),
      ),
    ],
  );

  Widget _loadingState(CalendarController controller) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (controller.appLoading || controller.googleLoading)
        const LinearProgressIndicator(),
      if (!controller.serverConnectionAvailable &&
          controller.googleAccount != null &&
          controller.googleLoaded &&
          controller.googleReceivedCount == 0)
        const Text('이 달의 Google 기본 캘린더에 일정이 없어요.'),
    ],
  );

  Widget _dayList(List<CalendarEvent> dayEvents) {
    final todoCount = dayEvents.where((event) => event.category == '할일').length;
    final scheduleCount = dayEvents.length - todoCount;
    final pendingEvents = CalendarScope.of(context).events.where((event) {
      if (!_selectedCategories.contains(_categoryOf(event)) ||
          event.isCompleted ||
          !const ['강의', '과제', '할일'].contains(event.category)) {
        return false;
      }
      return List.generate(
        7,
        (offset) => DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day + offset + 1,
        ),
      ).any(event.occursOn);
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_selectedDate.month}월 ${_selectedDate.day}일 ${_weekdayNames[_selectedDate.weekday - 1]}요일',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            dayEvents.isEmpty
                ? '여유로운 하루를 계획해보세요.'
                : '${scheduleCount + todoCount}개의 일정과 할일',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        if (dayEvents.isEmpty) ...[
          const SizedBox(height: 12),
          _CalendarEmptyState(
            category: _selectedCategories.length == 1
                ? _selectedCategories.single
                : '일정',
          ),
        ],
        for (final event in dayEvents)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              button: true,
              label: '${event.title} 상세보기',
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showEventDetails(event),
                child: _CalendarEventCard(event: event),
              ),
            ),
          ),
        ...[
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFE5EAF0)),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text('미완료 강의·과제·할일', style: AppTextStyles.heading2),
              ),
              const SizedBox(width: 8),
              Text(
                '${pendingEvents.length}개',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.calendarStatus,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '선택한 날짜 이후 7일 · 완료하지 않은 항목만 표시해요.',
            style: AppTextStyles.body.copyWith(color: AppColors.calendarStatus),
          ),
          const SizedBox(height: 32),
          if (pendingEvents.isEmpty)
            Text(
              '해당 기간에 미완료 항목이 없어요.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.calendarStatus,
              ),
            ),
          for (final event in pendingEvents)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                button: true,
                label: '${event.title} 상세보기',
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showEventDetails(event),
                  child: _CalendarEventCard(event: event),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _mobile(CalendarController controller, List<CalendarEvent> events) =>
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 20),
            _desktopFilters(),
            _loadingState(controller),
            const SizedBox(height: 16),
            _desktopGrid(controller),
            const SizedBox(height: 20),
            _dayList(events),
          ],
        ),
      );

  Widget _desktopFilters() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _filterPill(
        '전체',
        _selectedCategories.length == _categories.length,
        () => setState(
          () => _selectedCategories
            ..clear()
            ..addAll(_categories),
        ),
      ),
      for (final category in _categories)
        _filterPill(
          category,
          _selectedCategories.length == 1 &&
              _selectedCategories.contains(category),
          () => setState(
            () => _selectedCategories
              ..clear()
              ..add(category),
          ),
        ),
    ],
  );

  Widget _filterPill(String label, bool selected, VoidCallback onTap) =>
      ActionChip(
        // 선택 상태가 바뀌면 Material 색상 보간 없이 즉시 다시 그린다.
        key: ValueKey('calendar-filter-$label-$selected'),
        surfaceTintColor: Colors.transparent,
        onPressed: onTap,
        label: Text(label),
        backgroundColor: selected ? CalendarDesign.brand : Colors.white,
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        labelStyle: TextStyle(
          color: selected ? Colors.white : CalendarDesign.text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(
          color: selected ? Colors.transparent : const Color(0xFFE5EAF0),
        ),
        shape: const StadiumBorder(),
      );

  Widget _legends() => SizedBox(
    width: double.infinity,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 8,
          children: [
            _CalendarLegend('강의', CalendarDesign.category('강의')),
            _CalendarLegend('과제', CalendarDesign.category('과제')),
            _CalendarLegend('일정', CalendarDesign.category('일정')),
            _CalendarLegend('할일', CalendarDesign.category('할일')),
          ],
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 8,
          children: [
            _CalendarLegend('미완료', AppColors.calendarStatus, outlined: true),
            _CalendarLegend('완료', AppColors.calendarStatus),
          ],
        ),
      ],
    ),
  );

  Widget _desktopGrid(CalendarController controller) {
    final month = controller.month;
    final firstWeekday = DateTime(month.year, month.month).weekday;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((firstWeekday - 1 + days + 6) / 7).floor();
    final mobile = AppBreakpoints.of(context) == ScreenSize.mobile;
    final cellHeight = mobile ? 93.0 : 97.0;
    final visibleEvents = controller.events
        .where((event) => _selectedCategories.contains(_categoryOf(event)))
        .toList();
    return Container(
      key: const ValueKey('calendar-month-card'),
      padding: EdgeInsets.fromLTRB(
        mobile ? 13 : 24,
        mobile ? 20 : 26,
        mobile ? 13 : 24,
        19,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CalendarDesign.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${month.year}년 ${month.month}월',
                    style: TextStyle(
                      fontSize: mobile ? 17 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                tooltip: '이전 달',
                icon: const CalendarDesignIcon('previous'),
                onPressed: () =>
                    controller.setMonth(DateTime(month.year, month.month - 1)),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                tooltip: '다음 달',
                icon: const CalendarDesignIcon('next'),
                onPressed: () =>
                    controller.setMonth(DateTime(month.year, month.month + 1)),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                tooltip: '월 선택',
                icon: const CalendarDesignIcon('date'),
                onPressed: () => _pickMonth(controller),
              ),
              const Spacer(),
              IconButton(
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                tooltip: '일정 새로고침',
                icon: const Icon(Icons.refresh),
                onPressed: controller.refresh,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final name in _weekdayNames)
                Expanded(
                  child: Center(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var row = 0; row < rows; row++)
            Stack(
              alignment: Alignment.topCenter,
              children: [
                Row(
                  children: [
                    for (var column = 0; column < 7; column++)
                      Expanded(
                        child: _desktopDayCell(
                          controller,
                          row * 7 + column - firstWeekday + 2,
                          days,
                          cellHeight,
                        ),
                      ),
                  ],
                ),
                CalendarWeekEventBars(
                  dates: [
                    for (var column = 0; column < 7; column++)
                      DateTime(
                        month.year,
                        month.month,
                        row * 7 + column - firstWeekday + 2,
                      ),
                  ],
                  events: visibleEvents,
                  minimumHeight: cellHeight,
                  headerHeight: 0,
                  verticalOffset: 8,
                  categoryColor: CalendarDesign.category,
                  barHeight: 6,
                  laneHeight: 11,
                  maxVisibleLanes: 2,
                ),
              ],
            ),
          const Divider(height: 28),
          _legends(),
        ],
      ),
    );
  }

  Widget _desktopDayCell(
    CalendarController controller,
    int day,
    int days,
    double cellHeight,
  ) {
    final outsideMonth = day < 1 || day > days;
    final date = DateTime(controller.month.year, controller.month.month, day);
    final events = controller.events
        .where(
          (event) =>
              event.occursOn(date) &&
              (_selectedCategories.length == _categories.length ||
                  _selectedCategories.contains(_categoryOf(event))),
        )
        .toList();
    final selected =
        _selectedDate.year == date.year &&
        _selectedDate.month == date.month &&
        _selectedDate.day == date.day;
    return InkWell(
      key: ValueKey('calendar-day:${date.year}-${date.month}-${date.day}'),
      onTap: () => _selectDate(controller, date),
      child: Container(
        height: cellHeight,
        padding: const EdgeInsets.fromLTRB(3, 8, 3, 0),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFF0F2F5))),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? CalendarDesign.brand : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected
                        ? Colors.white
                        : outsideMonth
                        ? AppColors.calendarStatus.withValues(alpha: 0.6)
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final event in events.take(4))
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: event.isCompleted
                          ? CalendarDesign.category(event.category)
                          : Colors.transparent,
                      border: Border.all(
                        color: CalendarDesign.category(event.category),
                      ),
                    ),
                  ),
              ],
            ),
            if (cellHeight > 50 && events.length > 4)
              Text(
                '+${events.length - 4}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _desktop(CalendarController controller, List<CalendarEvent> events) =>
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 46, 40, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 25),
            _desktopFilters(),
            _loadingState(controller),
            const SizedBox(height: 25),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _desktopGrid(controller)),
                const SizedBox(width: 25),
                Expanded(flex: 2, child: _dayList(events)),
              ],
            ),
          ],
        ),
      );
}

class _CalendarEmptyState extends StatelessWidget {
  const _CalendarEmptyState({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: const _EmptyStateBorderPainter(),
    child: Container(
      key: const ValueKey('calendar-empty-state'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CalendarDesignIcon('empty'),
          const SizedBox(height: 20),
          Text(
            '표시할 $category${const ['일정', '할일'].contains(category) ? '이' : '가'} 없어요.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontSize: 13,
              color: AppColors.calendarStatus,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '오른쪽 아래 + 버튼으로 일정이나 할일을 추가해보세요.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontSize: 11,
              color: AppColors.calendarStatus,
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyStateBorderPainter extends CustomPainter {
  const _EmptyStateBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDCE4F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75),
          const Radius.circular(24),
        ),
      );
    for (final metric in path.computeMetrics()) {
      for (var offset = 0.0; offset < metric.length; offset += 7) {
        canvas.drawPath(metric.extractPath(offset, offset + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EmptyStateBorderPainter oldDelegate) => false;
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initialMonth});

  final DateTime initialMonth;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int year = widget.initialMonth.year;
  late int month = widget.initialMonth.month;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('표시할 월 선택', style: AppTextStyles.heading2),
              const SizedBox(height: 20),
              Row(
                children: [
                  IconButton(
                    tooltip: '이전 연도',
                    onPressed: year > 2000
                        ? () => setState(() => year--)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '$year년',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '다음 연도',
                    onPressed: year < 2100
                        ? () => setState(() => year++)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.5,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final value = index + 1;
                  final selected = month == value;
                  return OutlinedButton(
                    onPressed: () => setState(() => month = value),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: selected
                          ? const Color(0xFF3778C2)
                          : Colors.white,
                      foregroundColor: selected
                          ? Colors.white
                          : AppColors.textPrimary,
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFF3778C2)
                            : const Color(0xFFE5EAF0),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('$value월'),
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, DateTime(year, month)),
                    child: const Text('적용'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarEventCard extends StatelessWidget {
  const _CalendarEventCard({required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final presentation = CalendarEventPresentation(
      event: event,
      now: DateTime.now(),
    );
    if (event.category == '할일') return _todoCard(presentation);
    final color = CalendarDesign.category(event.category);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EBF0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 3, height: 58, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    event.category,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  event.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                _footer(presentation),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _todoCard(CalendarEventPresentation presentation) {
    final color = CalendarDesign.category(event.category);
    Widget badge(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EBF0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: event.isCompleted ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.3),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                badge('할일'),
                const SizedBox(height: 8),
                Text(
                  event.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                _footer(presentation),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(CalendarEventPresentation presentation) {
    final statusColor = presentation.isOverdue
        ? AppColors.error
        : CalendarDesign.category(event.category);
    return Row(
      children: [
        Expanded(
          child: Text(
            presentation.timeLabel,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.calendarStatus,
            ),
          ),
        ),
        if (presentation.hasDeadline) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              presentation.statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend(this.label, this.color, {this.outlined = false});
  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : color,
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}
