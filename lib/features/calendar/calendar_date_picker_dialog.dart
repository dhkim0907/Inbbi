import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// 일정 입력창에서 사용하는 한글 날짜 선택창.
class CalendarDatePickerDialog extends StatefulWidget {
  const CalendarDatePickerDialog({super.key, required this.initialDate});

  final DateTime initialDate;

  @override
  State<CalendarDatePickerDialog> createState() =>
      _CalendarDatePickerDialogState();
}

class _CalendarDatePickerDialogState extends State<CalendarDatePickerDialog> {
  static const _blue = Color(0xFF3778C2);
  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  late DateTime _selected;
  late DateTime _month;
  bool _choosingMonth = false;

  @override
  void initState() {
    super.initState();
    _selected = DateUtils.dateOnly(widget.initialDate);
    _month = DateTime(_selected.year, _selected.month);
  }

  void _move(int offset) => setState(() {
    _month = _choosingMonth
        ? DateTime(_month.year + offset, _month.month)
        : DateTime(_month.year, _month.month + offset);
  });

  Widget _monthChoices() => GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 3,
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: 1.7,
    children: [
      for (var month = 1; month <= 12; month++)
        TextButton(
          onPressed: () => setState(() {
            _month = DateTime(_month.year, month);
            _choosingMonth = false;
          }),
          style: TextButton.styleFrom(
            foregroundColor: _month.month == month
                ? _blue
                : AppColors.textPrimary,
            backgroundColor: _month.month == month
                ? const Color(0xFFEFF5FC)
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text('$month월'),
        ),
    ],
  );

  Widget _days() {
    final leading = _month.weekday - 1;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final count = ((leading + days + 6) ~/ 7) * 7;
    final today = DateUtils.dateOnly(DateTime.now());
    return Column(
      children: [
        Row(
          children: [
            for (final name in _weekdays)
              Expanded(
                child: Center(child: Text(name, style: AppTextStyles.caption)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 42,
          ),
          itemBuilder: (context, index) {
            final day = index - leading + 1;
            if (day < 1 || day > days) return const SizedBox.shrink();
            final date = DateTime(_month.year, _month.month, day);
            final selected = date == _selected;
            final isToday = date == today;
            return Center(
              child: Semantics(
                label: '${date.year}년 ${date.month}월 $day일',
                selected: selected,
                button: true,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Material(
                    color: selected ? _blue : Colors.transparent,
                    shape: CircleBorder(
                      side: isToday && !selected
                          ? const BorderSide(color: _blue)
                          : BorderSide.none,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => setState(() => _selected = date),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : isToday
                                ? _blue
                                : AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: selected || isToday
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPrevious = _choosingMonth
        ? _month.year > 2000
        : _month.isAfter(DateTime(2000));
    final canNext = _choosingMonth
        ? _month.year < 2100
        : _month.isBefore(DateTime(2100, 12));
    return Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        key: const ValueKey('calendar-date-picker-content'),
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('날짜 선택', style: AppTextStyles.heading2),
                  ),
                  IconButton(
                    tooltip: '날짜 선택 닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.calendarStatus,
                      size: 22,
                    ),
                  ),
                ],
              ),
              Text(
                '${_selected.year}년 ${_selected.month}월 ${_selected.day}일 (${_weekdays[_selected.weekday - 1]})',
                style: const TextStyle(
                  color: _blue,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  IconButton(
                    tooltip: _choosingMonth ? '이전 연도' : '이전 달',
                    onPressed: canPrevious ? () => _move(-1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _choosingMonth = !_choosingMonth),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _choosingMonth
                                    ? '${_month.year}년'
                                    : '${_month.year}년 ${_month.month}월',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _choosingMonth
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _choosingMonth ? '다음 연도' : '다음 달',
                    onPressed: canNext ? () => _move(1) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_choosingMonth) _monthChoices() else _days(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    style: FilledButton.styleFrom(backgroundColor: _blue),
                    child: const Text('확인'),
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
