import 'package:flutter/widgets.dart';

import 'calendar_controller.dart';

class CalendarScope extends InheritedNotifier<CalendarController> {
  const CalendarScope({
    super.key,
    required CalendarController controller,
    required super.child,
  }) : super(notifier: controller);

  static CalendarController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CalendarScope>()!.notifier!;
}
