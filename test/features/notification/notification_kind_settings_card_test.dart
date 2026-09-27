import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/features/notification/notification_kind_settings_card.dart';
import 'package:inbbi/features/notification/notification_scope.dart';
import 'package:inbbi/features/notification/notification_service.dart';

class _MemoryStorage implements NotificationStorage {
  @override
  Future<String?> load() async => null;
  @override
  Future<void> save(String value) async {}
}

void main() {
  for (final width in [390.0, 840.0, 1280.0]) {
    testWidgets('알림 종류 선택 카드 너비 $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = NotificationService(_MemoryStorage());
      addTearDown(service.dispose);
      await service.initialize();
      await tester.pumpWidget(
        NotificationScope(
          service: service,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: NotificationKindSettingsCard(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('마감'));
      await tester.pump();
      expect(service.accepts(NotificationKind.deadline), false);
      expect(tester.takeException(), isNull);
    });
  }
}
