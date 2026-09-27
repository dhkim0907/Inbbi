import 'package:flutter/material.dart';
import 'realtime_service.dart';

class RealtimeScope extends InheritedNotifier<NotificationRealtimeService> {
  const RealtimeScope({
    super.key,
    required NotificationRealtimeService service,
    required super.child,
  }) : super(notifier: service);
  static NotificationRealtimeService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RealtimeScope>()?.notifier;
}
