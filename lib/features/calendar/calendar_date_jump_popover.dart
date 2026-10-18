import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'calendar_date_picker_dialog.dart';
import 'calendar_design.dart';

Future<DateTime?> showCalendarDateJumpPopover(
  BuildContext context, {
  required Rect anchor,
  required DateTime initialDate,
}) => showGeneralDialog<DateTime>(
  context: context,
  barrierDismissible: true,
  barrierLabel: '날짜 선택 닫기',
  barrierColor: Colors.transparent,
  transitionDuration: const Duration(milliseconds: 120),
  pageBuilder: (context, animation, secondaryAnimation) => Padding(
    padding: MediaQuery.viewInsetsOf(context),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(260.0, constraints.maxWidth - 32);
          final top = (anchor.bottom + 8 - MediaQuery.paddingOf(context).top)
              .clamp(16.0, math.max(16.0, constraints.maxHeight - 240))
              .toDouble();
          return Stack(
            children: [
              Positioned(
                left: anchor.left.clamp(
                  16.0,
                  constraints.maxWidth - width - 16,
                ),
                top: top,
                width: width,
                child: Material(
                  color: Colors.white,
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: CalendarDesign.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.max(0, constraints.maxHeight - top - 16),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: _DateJumpForm(initialDate: initialDate),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  ),
);

class _DateJumpForm extends StatefulWidget {
  const _DateJumpForm({required this.initialDate});
  final DateTime initialDate;

  @override
  State<_DateJumpForm> createState() => _DateJumpFormState();
}

class _DateJumpFormState extends State<_DateJumpForm> {
  final _form = GlobalKey<FormState>();
  late final _input = TextEditingController(text: _format(widget.initialDate));

  String _format(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime? _parse(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    final date = DateTime.tryParse(value);
    if (date == null || date.year < 2000 || date.year > 2100) return null;
    return _format(date) == value ? date : null;
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _parse(_input.text));
    }
  }

  Future<void> _chooseDate() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => CalendarDatePickerDialog(
        initialDate: _parse(_input.text) ?? widget.initialDate,
      ),
    );
    if (picked != null && mounted) {
      _input.text = _format(picked);
      _form.currentState!.validate();
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '날짜 선택',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CalendarDesign.muted,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _input,
          autofocus: true,
          keyboardType: TextInputType.datetime,
          textInputAction: TextInputAction.go,
          style: const TextStyle(fontSize: 16, color: CalendarDesign.text),
          decoration: InputDecoration(
            hintText: 'YYYY-MM-DD',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: CalendarDesign.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: CalendarDesign.brand,
                width: 2,
              ),
            ),
            suffixIcon: IconButton(
              tooltip: '달력에서 날짜 선택',
              onPressed: _chooseDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
            ),
          ),
          validator: (value) => _parse(value ?? '') == null
              ? '2000~2100년의 올바른 날짜를 입력해 주세요.'
              : null,
          onFieldSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                _input.text = _format(DateTime.now());
                _form.currentState!.validate();
              },
              style: TextButton.styleFrom(
                foregroundColor: CalendarDesign.brand,
              ),
              child: const Text('오늘'),
            ),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: CalendarDesign.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('이동'),
            ),
          ],
        ),
      ],
    ),
  );
}
