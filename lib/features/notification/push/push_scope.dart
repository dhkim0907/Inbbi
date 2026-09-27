import 'package:flutter/material.dart';
import 'push_service.dart';

class PushScope extends InheritedNotifier<PushService> {
  const PushScope({
    super.key,
    required PushService service,
    required super.child,
  }) : super(notifier: service);
  static PushService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PushScope>()?.notifier;
}
