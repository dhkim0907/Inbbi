import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF3D5AFE);
  static const Color secondary = Color(0xFF00BFA5);
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1A1C1E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color calendarLecture = Color(0xFF5865E8);
  static const Color calendarAssignment = Color(0xFFD49314);
  static const Color calendarSchedule = Color(0xFFAC59D6);
  static const Color calendarTodo = Color(0xFF25AE91);
  static const Color calendarStatus = Color(0xFF94A3B8);

  static Color calendarCategory(String category) => switch (category) {
    '강의' => calendarLecture,
    '과제' => calendarAssignment,
    '할일' => calendarTodo,
    _ => calendarSchedule,
  };

  static const Color error = Color(0xFFE53935);

  // 강의/카테고리 커스텀 배지 색상 팔레트 (요구사항 6)
  static const List<Color> categoryPalette = [
    Color(0xFFEF5350),
    Color(0xFFFFA726),
    Color(0xFFFFEE58),
    Color(0xFF66BB6A),
    Color(0xFF29B6F6),
    Color(0xFF7E57C2),
    Color(0xFFEC407A),
  ];
}
