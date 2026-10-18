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
import 'calendar_add_menu.dart';
import 'calendar_date_jump_popover.dart';

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
  bool _choosingAdd = false;
  final _addButtonKey = GlobalKey();
  final _dateButtonKey = GlobalKey();

  Future<void> _chooseAdd(CalendarController controller) async {
    if (_choosingAdd || _addingEvent) return;
    _choosingAdd = true;
    String? category;
    try {
      final box =
          _addButtonKey.currentContext!.findRenderObject()! as RenderBox;
      category = await showCalendarAddMenu(
        context,
        anchor: box.localToGlobal(Offset.zero) & box.size,
        buttonSize: box.size.width,
      );
    } finally {
      _choosingAdd = false;
    }
    if (category != null && mounted) {
      await _addEvent(controller, category);
    }
  }

  Future<void> _addEvent(CalendarController controller, String category) async {
    if (_addingEvent) return;
    _addingEvent = true;
    try {
      final draft = await showDialog<CalendarEventDraft>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CalendarEventDialog(
          initialDate: _selectedDate,
          initialCategory: category,
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

  Future<void> _pickDate(CalendarController controller) async {
    final box = _dateButtonKey.currentContext!.findRenderObject()! as RenderBox;
    final picked = await showCalendarDateJumpPopover(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      initialDate: _selectedDate,
    );
    if (picked == null || !mounted) return;
    _selectDate(controller, picked);
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
        key: _addButtonKey,
        width: AppBreakpoints.of(context) == ScreenSize.mobile ? 52 : 57,
        height: AppBreakpoints.of(context) == ScreenSize.mobile ? 52 : 57,
        child: FloatingActionButton(
          heroTag: 'calendar-add-event',
          tooltip: '일정 및 할일 추가',
          backgroundColor: CalendarDesign.brand,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          elevation: 6,
          onPressed: () => _chooseAdd(controller),
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
    final mobile = AppBreakpoints.of(context) == ScreenSize.mobile;
    DateTime pendingDate(CalendarEvent event) {
      final end = event.allDay
          ? event.end.subtract(const Duration(days: 1))
          : event.end.toLocal();
      return DateTime(end.year, end.month, end.day);
    }

    final pendingDays = [
      for (var offset = 1; offset <= 7; offset++)
        DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day + offset,
        ),
    ];
    final pendingEvents = CalendarScope.of(context).events.where((event) {
      if (!_selectedCategories.contains(_categoryOf(event)) ||
          event.isCompleted ||
          !const ['강의', '과제', '할일'].contains(event.category)) {
        return false;
      }
      return pendingDays.any(
        (date) => DateUtils.isSameDay(pendingDate(event), date),
      );
    }).toList()..sort((a, b) => a.end.compareTo(b.end));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_selectedDate.month}월 ${_selectedDate.day}일 ${_weekdayNames[_selectedDate.weekday - 1]}요일',
          style: TextStyle(
            fontSize: mobile ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: CalendarDesign.text,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            dayEvents.isEmpty
                ? '여유로운 하루를 계획해보세요.'
                : '${scheduleCount + todoCount}개의 일정과 할일',
            style: TextStyle(
              fontSize: mobile ? 11 : 12,
              color: CalendarDesign.muted,
            ),
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
        if (_selectedCategories.length == _categories.length) ...[
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFE5EAF0)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  '미완료 강의·과제·할일',
                  style: TextStyle(
                    fontSize: mobile ? 14 : 16,
                    fontWeight: FontWeight.w700,
                    color: CalendarDesign.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${pendingEvents.length}개',
                style: const TextStyle(
                  fontSize: 11,
                  color: CalendarDesign.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '선택한 날짜 이후 7일 · 완료하지 않은 항목만 표시해요',
            style: TextStyle(
              fontSize: mobile ? 10 : 12,
              height: 1.5,
              color: CalendarDesign.muted,
            ),
          ),
          const SizedBox(height: 6),
          if (pendingEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text(
                '해당 기간에 미완료 항목이 없어요.',
                style: TextStyle(fontSize: 11, color: CalendarDesign.muted),
              ),
            ),
          for (final date in pendingDays)
            if (pendingEvents.any(
              (event) => DateUtils.isSameDay(pendingDate(event), date),
            )) ...[
              Padding(
                padding: const EdgeInsets.only(top: 11, bottom: 10),
                child: Text(
                  '${date.month}월 ${date.day}일 ${_weekdayNames[date.weekday - 1]}요일',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64738A),
                  ),
                ),
              ),
              for (final event in pendingEvents.where(
                (event) => DateUtils.isSameDay(pendingDate(event), date),
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    button: true,
                    label: '${event.title} 상세보기',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(17),
                      onTap: () => _showEventDetails(event),
                      child: _CalendarEventCard(event: event, compact: true),
                    ),
                  ),
                ),
            ],
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
            const SizedBox(height: 25),
            _filters(),
            _loadingState(controller),
            const SizedBox(height: 20),
            _desktopGrid(controller),
            const SizedBox(height: 25),
            _dayList(events),
          ],
        ),
      );

  Widget _filters() {
    final mobile = AppBreakpoints.of(context) == ScreenSize.mobile;
    final pills = [
      _filterPill(
        '전체',
        _selectedCategories.length == _categories.length,
        () => setState(
          () => _selectedCategories
            ..clear()
            ..addAll(_categories),
        ),
        expand: mobile,
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
          expand: mobile,
        ),
    ];
    if (!mobile) {
      return Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Wrap(spacing: 9, runSpacing: 8, children: pills),
      );
    }
    return Row(
      children: [
        for (var i = 0; i < pills.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(child: pills[i]),
        ],
      ],
    );
  }

  Widget _filterPill(
    String label,
    bool selected,
    VoidCallback onTap, {
    bool expand = false,
  }) {
    final selectedColor = label == '전체'
        ? CalendarDesign.brand
        : CalendarDesign.category(label);
    Widget chip(double? labelWidth) => Semantics(
      selected: selected,
      child: SizedBox(
        height: expand ? 39 : 41,
        child: ActionChip(
          key: ValueKey('calendar-filter-$label-$selected'),
          onPressed: onTap,
          surfaceTintColor: Colors.transparent,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
          labelPadding: EdgeInsets.zero,
          labelStyle: TextStyle(
            fontFamily: 'NotoSansKR',
            fontSize: expand ? 12 : 13,
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : CalendarDesign.text,
          ),
          backgroundColor: selected ? selectedColor : Colors.white,
          side: BorderSide(
            color: selected ? selectedColor : CalendarDesign.border,
          ),
          shape: const StadiumBorder(),
          label: SizedBox(
            width: labelWidth,
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
    if (!expand) return SizedBox(width: 70, child: chip(54));
    return LayoutBuilder(
      builder: (context, constraints) =>
          chip((constraints.maxWidth - 16).clamp(0, double.infinity)),
    );
  }

  Widget _legends() => SizedBox(
    width: double.infinity,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
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
          spacing: 14,
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
                key: _dateButtonKey,
                tooltip: '날짜 선택',
                icon: const CalendarDesignIcon('date'),
                onPressed: () => _pickDate(controller),
              ),
              const Spacer(),
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
        padding: const EdgeInsets.fromLTRB(57.6, 46, 57.6, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 25),
            _filters(),
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

class _CalendarEventCard extends StatelessWidget {
  const _CalendarEventCard({required this.event, this.compact = false});
  final CalendarEvent event;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final presentation = CalendarEventPresentation(
      event: event,
      now: DateTime.now(),
    );
    if (event.category == '할일') return _todoCard(context, presentation);
    final mobile = AppBreakpoints.of(context) == ScreenSize.mobile;
    final color = CalendarDesign.category(event.category);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(mobile ? 15 : 19, 18, mobile ? 15 : 19, 15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: CalendarDesign.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4.5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      event.category,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      color: CalendarDesign.text,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _footer(presentation),
                  if (!compact && event.memo.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.memo,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.6,
                        color: CalendarDesign.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _todoCard(
    BuildContext context,
    CalendarEventPresentation presentation,
  ) {
    final mobile = AppBreakpoints.of(context) == ScreenSize.mobile;
    final color = CalendarDesign.category(event.category);
    Widget badge(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
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
      padding: EdgeInsets.fromLTRB(mobile ? 15 : 19, 18, mobile ? 15 : 19, 15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: CalendarDesign.border),
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
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: CalendarDesign.text,
                  ),
                ),
                const SizedBox(height: 5),
                _footer(presentation),
                if (!compact && event.memo.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    event.memo,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      color: CalendarDesign.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _metaLabel(CalendarEventPresentation presentation) {
    if (compact && presentation.hasDeadline) {
      final deadline = event.allDay
          ? event.end.subtract(const Duration(minutes: 1))
          : event.end.toLocal();
      return '마감 ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}';
    }
    if (presentation.hasDeadline) return presentation.timeLabel;
    final parts = [event.allDay ? '하루 종일' : presentation.timeLabel];
    if (event.location.trim().isNotEmpty) parts.add(event.location);
    if (event.allDay) {
      final end = event.end.subtract(const Duration(days: 1));
      String date(DateTime value) =>
          '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
      if (!DateUtils.isSameDay(event.start, end)) {
        parts.add('${date(event.start)} ~ ${date(end)}');
      }
    }
    return parts.join(' · ');
  }

  Widget _footer(CalendarEventPresentation presentation) {
    final statusColor = presentation.isOverdue
        ? AppColors.error
        : CalendarDesign.category(event.category);
    return Row(
      children: [
        Expanded(
          child: Text(
            _metaLabel(presentation),
            style: const TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Color(0xFF8895A7),
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
                fontSize: 9,
                height: 1.4,
                fontWeight: FontWeight.w600,
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
    padding: EdgeInsets.zero,
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
          style: const TextStyle(fontSize: 9, color: Color(0xFF9BA6B6)),
        ),
      ],
    ),
  );
}
