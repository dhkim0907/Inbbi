import 'package:flutter/widgets.dart';

import 'auth_session_service.dart';

class AuthScope extends InheritedWidget {
  const AuthScope({super.key, required this.service, required super.child});

  final AuthSessionService service;

  static AuthSessionService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope is missing');
    return scope!.service;
  }

  @override
  bool updateShouldNotify(AuthScope oldWidget) => service != oldWidget.service;
}
