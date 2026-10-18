import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'calendar_event.dart';
import 'app_calendar_api.dart';
import 'calendar_event_writer.dart';
import 'google_calendar_api.dart';
import 'calendar_event_presentation.dart';

class CalendarEventDetailsDialog extends StatefulWidget {
  const CalendarEventDetailsDialog({
    super.key,
    required this.event,
    this.onEdit,
    this.onDelete,
  });

  final CalendarEvent event;
  final Future<CalendarEvent?> Function(CalendarEvent)? onEdit;
  final Future<void> Function(CalendarEvent)? onDelete;

  @override
  State<CalendarEventDetailsDialog> createState() =>
      _CalendarEventDetailsDialogState();
}

class _CalendarEventDetailsDialogState
    extends State<CalendarEventDetailsDialog> {
  late CalendarEvent event = widget.event;
  bool _busy = false;
  bool _deleting = false;
  String? _error;

  Future<void> _edit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await widget.onEdit!(event);
      if (updated != null && mounted) setState(() => event = updated);
    } catch (error) {
      if (mounted) setState(() => _error = _errorLabel(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _deleting = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('일정 삭제'),
          content: Text('“${event.title}” 일정을 삭제할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('삭제'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _deleting = true);
      await widget.onDelete!(event);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = _errorLabel(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _deleting = false;
        });
      }
    }
  }

  String _errorLabel(Object error) => switch (error) {
    CalendarAuthRequired() => '로그인이 만료되었어요. 다시 로그인해 주세요.',
    GoogleCalendarAuthRequired() => 'Google 일정 권한을 다시 허용해 주세요.',
    GoogleCalendarAccessDenied() => 'Google 일정에 접근할 권한이 없어요.',
    CalendarEventNotFound() => '일정을 찾을 수 없어요. 캘린더를 새로고침해 주세요.',
    CalendarUnavailable() => '일정 서비스를 사용할 수 없어요. 연결 설정을 확인해 주세요.',
    _ => '처리하지 못했어요. 네트워크 연결을 확인하고 다시 시도해 주세요.',
  };

  @override
  Widget build(BuildContext context) {
    final presentation = CalendarEventPresentation(
      event: event,
      now: DateTime.now(),
    );
    final color = AppColors.calendarCategory(event.category);
    final start = event.allDay ? event.start : event.start.toLocal();
    final end = event.allDay
        ? event.end.subtract(const Duration(days: 1))
        : event.end.toLocal();
    final date = presentation.hasDeadline ? end : start;
    final dateLabel =
        presentation.hasDeadline || DateUtils.isSameDay(start, end)
        ? _date(date)
        : '${_date(start)} ~ ${_date(end)}';
    final timeLabel = event.allDay
        ? '종일'
        : presentation.hasDeadline
        ? _time(end)
        : '${_time(start)}~ ${_time(end)}';
    final statusColor = presentation.isOverdue ? AppColors.error : color;

    return PopScope(
      canPop: !_busy,
      child: Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('상세 내용', style: AppTextStyles.heading1),
                    ),
                    IconButton(
                      tooltip: '상세보기 닫기',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18),
                      color: AppColors.calendarStatus,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _badge(event.category, color),
                const SizedBox(height: 16),
                Text(event.title, style: AppTextStyles.heading1),
                if (presentation.hasDeadline) ...[
                  const SizedBox(height: 40),
                  _badge(presentation.statusLabel, statusColor),
                ],
                const SizedBox(height: 24),
                _field('날짜', dateLabel),
                const SizedBox(height: 24),
                _field('시간', timeLabel),
                if (event.location.trim().isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _field('장소', event.location),
                ],
                const SizedBox(height: 24),
                _field('메모', event.memo.trim().isEmpty ? '메모 없음' : event.memo),
                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                if (widget.onEdit != null || widget.onDelete != null) ...[
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      if (widget.onDelete != null)
                        TextButton(
                          onPressed: _busy ? null : _delete,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                          child: const Text('삭제'),
                        ),
                      const Spacer(),
                      if (_deleting)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      if (widget.onEdit != null) ...[
                        const SizedBox(width: 16),
                        FilledButton(
                          onPressed: _busy ? null : _edit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF3778C2),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(126, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('수정'),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
    ),
  );

  Widget _field(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 98,
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(color: AppColors.calendarStatus),
        ),
      ),
      Expanded(child: Text(value, style: AppTextStyles.body)),
    ],
  );

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
