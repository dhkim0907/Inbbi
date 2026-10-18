import 'package:flutter/material.dart';

import 'calendar_design.dart';

/// 캘린더의 추가 버튼 위에 일정/할일 선택 메뉴를 표시한다.
Future<String?> showCalendarAddMenu(
  BuildContext context, {
  required Rect anchor,
  required double buttonSize,
}) => showGeneralDialog<String>(
  context: context,
  barrierDismissible: true,
  barrierLabel: '추가 메뉴 닫기',
  barrierColor: Colors.black.withValues(alpha: 0.18),
  transitionDuration: const Duration(milliseconds: 120),
  pageBuilder: (context, animation, secondaryAnimation) {
    final size = MediaQuery.sizeOf(context);
    return Stack(
      children: [
        Positioned(
          right: (size.width - anchor.right).clamp(16, size.width - 170),
          bottom: (size.height - anchor.bottom).clamp(16, size.height - 180),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final category in ['할일', '일정']) ...[
                  SizedBox(
                    width: 154,
                    height: 40,
                    child: FilledButton.icon(
                      key: ValueKey('calendar-add-$category'),
                      onPressed: () => Navigator.pop(context, category),
                      style: FilledButton.styleFrom(
                        backgroundColor: CalendarDesign.brand,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        textStyle: const TextStyle(
                          fontFamily: 'NotoSansKR',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: const StadiumBorder(),
                      ),
                      icon: Icon(
                        category == '할일'
                            ? Icons.check_circle_outline
                            : Icons.calendar_today_outlined,
                        size: 18,
                      ),
                      label: Text('$category 추가'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 4),
                SizedBox.square(
                  dimension: buttonSize,
                  child: FloatingActionButton(
                    heroTag: null,
                    tooltip: '추가 메뉴 닫기',
                    backgroundColor: const Color(0xFFE8F1FF),
                    foregroundColor: CalendarDesign.brand,
                    shape: const CircleBorder(),
                    elevation: 0,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  },
);
