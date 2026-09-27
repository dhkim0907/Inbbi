import 'package:flutter/material.dart';
import 'notification_service.dart';

class NotificationScope extends InheritedNotifier<NotificationService> {
  const NotificationScope({
    super.key,
    required NotificationService service,
    required super.child,
  }) : super(notifier: service);
  static NotificationService of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<NotificationScope>()!
      .notifier!;
}

class NotificationNavigation extends InheritedWidget {
  const NotificationNavigation({
    super.key,
    required this.select,
    required super.child,
  });
  final ValueChanged<int> select;
  static void open(BuildContext context, int index) => context
      .dependOnInheritedWidgetOfExactType<NotificationNavigation>()!
      .select(index);
  @override
  bool updateShouldNotify(NotificationNavigation oldWidget) =>
      select != oldWidget.select;
}
