import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Figma ‘인삐 UI’ 캘린더 전용 값. 다른 화면의 공통 테마는 유지한다.
class CalendarDesign {
  CalendarDesign._();

  static const brand = Color(0xFF3674BF);
  static const background = Color(0xFFF6F7F9);
  static const text = Color(0xFF252D3A);
  static const muted = Color(0xFF8490A3);
  static const border = Color(0xFFE6EAF0);

  static Color category(String category) => switch (category) {
    '강의' => const Color(0xFF4D68EE),
    '과제' => const Color(0xFFC08B19),
    '할일' => const Color(0xFF28A881),
    _ => const Color(0xFFA65BCE),
  };
}

class CalendarDesignIcon extends StatelessWidget {
  const CalendarDesignIcon(this.name, {super.key});
  final String name;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: switch (name) {
      'date' => 23,
      'empty' => 35,
      'add' => 27,
      'input_date' => 14,
      'input_time' => 14.7,
      _ => 21,
    },
    child: SvgPicture.asset(
      'assets/icons/calendar/$name.svg',
      excludeFromSemantics: true,
    ),
  );
}
