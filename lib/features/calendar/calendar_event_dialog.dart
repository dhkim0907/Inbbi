import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_calendar_api.dart';
import 'calendar_date_picker_dialog.dart';
import 'calendar_event_draft.dart';
import 'calendar_event.dart';
import 'calendar_event_writer.dart';
import 'google_calendar_api.dart';

class CalendarEventDialog extends StatefulWidget {
  const CalendarEventDialog({
    super.key,
    required this.initialDate,
    required this.onSave,
    this.initialEvent,
  });

  final DateTime initialDate;
  final CalendarEvent? initialEvent;
  final Future<void> Function(CalendarEventDraft) onSave;

  @override
  State<CalendarEventDialog> createState() => _CalendarEventDialogState();
}

class _CalendarEventDialogState extends State<CalendarEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _memo = TextEditingController();
  String _category = '일정';
  CalendarSaveTarget _saveTarget = CalendarSaveTarget.googleCalendar;
  static const _blue = Color(0xFF3778C2);
  static const _labelColor = Color(0xFF64748B);
  static const _borderColor = Color(0xFFDDE4EF);
  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  bool _allDay = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startDate = DateUtils.dateOnly(widget.initialDate);
    _endDate = _startDate;
    final event = widget.initialEvent;
    if (event != null) {
      final start = event.allDay ? event.start : event.start.toLocal();
      final end = event.allDay
          ? event.end.subtract(const Duration(days: 1))
          : event.end.toLocal();
      _title.text = event.title;
      _location.text = event.location;
      _memo.text = event.memo;
      _category = event.category;
      _allDay = event.allDay;
      _startDate = DateTime(start.year, start.month, start.day);
      _endDate = DateTime(end.year, end.month, end.day);
      _startTime = TimeOfDay.fromDateTime(start);
      _endTime = TimeOfDay.fromDateTime(end);
      _saveTarget =
          event.source == CalendarSource.google || event.calendarId == 'primary'
          ? CalendarSaveTarget.googleCalendar
          : CalendarSaveTarget.appOnly;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _memo.dispose();
    super.dispose();
  }

  String _dateLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool start) async {
    final date = await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (_) =>
          CalendarDatePickerDialog(initialDate: start ? _startDate : _endDate),
    );
    if (date == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = date;
        if (_endDate.isBefore(date)) _endDate = date;
      } else {
        _endDate = date;
      }
      _error = null;
    });
  }

  Future<void> _pickTime(bool start) async {
    final time = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
    );
    if (time == null || !mounted) return;
    setState(() {
      if (start) {
        _startTime = time;
      } else {
        _endTime = time;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final start = _allDay
        ? _startDate
        : DateTime(
            _startDate.year,
            _startDate.month,
            _startDate.day,
            _startTime.hour,
            _startTime.minute,
          );
    final end = _allDay
        ? DateTime(_endDate.year, _endDate.month, _endDate.day + 1)
        : DateTime(
            _endDate.year,
            _endDate.month,
            _endDate.day,
            _endTime.hour,
            _endTime.minute,
          );
    if (_endDate.isBefore(_startDate) || !end.isAfter(start)) {
      setState(() => _error = '종료 날짜와 시간은 시작 이후로 설정해 주세요.');
      return;
    }
    final draft = CalendarEventDraft(
      title: _title.text,
      start: start,
      end: end,
      allDay: _allDay,
      category: _category,
      location: _location.text,
      memo: _memo.text,
      saveTarget: _saveTarget,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(draft);
      if (mounted) Navigator.pop(context, draft);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (error) {
          GoogleCalendarAuthRequired() =>
            '설정에서 Google 캘린더를 연결하거나 일정 권한을 다시 허용해 주세요.',
          GoogleCalendarAccessDenied() =>
            'Google 캘린더에 일정을 저장할 권한이 없어요. 설정에서 권한을 확인해 주세요.',
          CalendarAuthRequired() => '로그인이 만료되었어요. 다시 로그인해 주세요.',
          CalendarUnavailable() => '일정 저장 서비스를 사용할 수 없어요. 연결 설정을 확인해 주세요.',
          CalendarEventNotFound() => '일정 저장 API를 찾을 수 없어요. 서버 설정을 확인해 주세요.',
          _ => '일정을 저장하지 못했어요. 네트워크 연결을 확인하고 다시 시도해 주세요.',
        };
      });
    }
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF858585)),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _borderColor, width: 1.3),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF8CB7F0), width: 3),
    ),
  );

  Widget _label(String text, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text.rich(
      TextSpan(
        text: text,
        style: const TextStyle(
          color: _labelColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: _blue),
            ),
        ],
      ),
    ),
  );

  String _timeLabel(TimeOfDay time) =>
      '${time.hour < 12 ? '오전' : '오후'} ${(time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod).toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Widget _pickerField(String label, bool start, {required bool date}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(label),
      SizedBox(
        width: double.infinity,
        height: 58,
        child: OutlinedButton(
          onPressed: _saving || (!date && _allDay)
              ? null
              : () => date ? _pickDate(start) : _pickTime(start),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            side: const BorderSide(color: _borderColor, width: 1.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  date
                      ? _dateLabel(start ? _startDate : _endDate)
                      : _allDay
                      ? '하루 종일'
                      : _timeLabel(start ? _startTime : _endTime),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                date ? Icons.calendar_today_outlined : Icons.access_time,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _dateTimeRow(bool start) => LayoutBuilder(
    builder: (context, constraints) {
      final date = _pickerField(start ? '시작 날짜' : '종료 날짜', start, date: true);
      final time = _pickerField(start ? '시작 시간' : '종료 시간', start, date: false);
      if (constraints.maxWidth < 400) {
        return Column(children: [date, const SizedBox(height: 18), time]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: date),
          const SizedBox(width: 16),
          Expanded(child: time),
        ],
      );
    },
  );

  Widget _tabs() => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F4F9),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        for (final category
            in widget.initialEvent != null &&
                    !const ['일정', '할일'].contains(widget.initialEvent!.category)
                ? [widget.initialEvent!.category]
                : ['일정', '할일'])
          Expanded(
            child: Semantics(
              selected: _category == category,
              child: TextButton(
                onPressed: _saving
                    ? null
                    : () => setState(() => _category = category),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: _category == category
                      ? Colors.white
                      : Colors.transparent,
                  foregroundColor: _category == category
                      ? _blue
                      : AppColors.calendarStatus,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(category),
              ),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600 ? 24 : 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.initialEvent == null ? '일정 추가' : '일정 수정',
                      style: AppTextStyles.heading1.copyWith(fontSize: 28),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.calendarStatus,
                      size: 26,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _tabs(),
                        const SizedBox(height: 28),
                        _label('제목', required: true),
                        TextFormField(
                          key: const ValueKey('calendar-event-title'),
                          controller: _title,
                          autofocus: true,
                          enabled: !_saving,
                          decoration: _inputDecoration(
                            _category == '할일' ? '어떤 할일이 있나요?' : '어떤 일정이 있나요?',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? '일정 제목을 입력해 주세요.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '하루 종일',
                                style: TextStyle(
                                  color: _labelColor,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Checkbox(
                              value: _allDay,
                              activeColor: _blue,
                              onChanged: _saving || widget.initialEvent != null
                                  ? null
                                  : (value) => setState(() {
                                      _allDay = value!;
                                      _error = null;
                                    }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _dateTimeRow(true),
                        const SizedBox(height: 24),
                        _dateTimeRow(false),
                        const SizedBox(height: 24),
                        _label('장소'),
                        TextFormField(
                          key: const ValueKey('calendar-event-location'),
                          controller: _location,
                          enabled: !_saving,
                          decoration: _inputDecoration('장소를 입력하세요 (선택)'),
                        ),
                        const SizedBox(height: 24),
                        _label('메모'),
                        TextFormField(
                          key: const ValueKey('calendar-event-memo'),
                          controller: _memo,
                          enabled: !_saving,
                          minLines: 3,
                          maxLines: 5,
                          decoration: _inputDecoration('기억할 내용을 남겨주세요 (선택)'),
                        ),
                        const SizedBox(height: 24),
                        _label('저장 대상'),
                        Row(
                          children: [
                            Checkbox(
                              key: const ValueKey('calendar-event-google-save'),
                              value:
                                  _saveTarget ==
                                  CalendarSaveTarget.googleCalendar,
                              activeColor: _blue,
                              onChanged: _saving || widget.initialEvent != null
                                  ? null
                                  : (value) => setState(() {
                                      _saveTarget = value!
                                          ? CalendarSaveTarget.googleCalendar
                                          : CalendarSaveTarget.appOnly;
                                      _error = null;
                                    }),
                            ),
                            const Expanded(child: Text('구글 캘린더에도 저장합니다.')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Text(
                        //   _saveTarget == CalendarSaveTarget.appOnly
                        //       ? '다른 기기에서도 확인할 수 있어요.'
                        //       : '앱 및 연결된 Google 캘린더에도 저장해요.',
                        //   style: AppTextStyles.caption,
                        // ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _blue),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('저장'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
