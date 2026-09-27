import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/features/notification/notification_page.dart';
import 'package:inbbi/features/notification/notification_scope.dart';
import 'package:inbbi/features/notification/notification_service.dart';
import 'notification_service_test.dart' show MemoryStorage, event;

void main() {
  for (final width in [390.0, 839.0, 840.0, 1280.0]) {
    testWidgets('너비 $width 목록, 필터, 읽음, 이동 및 배지', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = NotificationService(MemoryStorage());
      addTearDown(service.dispose);
      await service.initialize();
      int? destination;
      await tester.pumpWidget(
        NotificationScope(
          service: service,
          child: MaterialApp(
            home: NotificationNavigation(
              select: (index) => destination = index,
              child: const NotificationPage(),
            ),
          ),
        ),
      );
      expect(find.text('표시할 알림이 없어요.'), findsOneWidget);
      await service.receive(event('a'));
      await tester.pumpAndSettle();
      expect(find.text('알림 a'), findsOneWidget);
      expect(find.byTooltip('알림, 읽지 않은 알림 1개'), findsOneWidget);
      await tester.tap(find.text('강의'));
      await tester.pumpAndSettle();
      expect(find.text('표시할 알림이 없어요.'), findsOneWidget);
      await tester.tap(find.text('전체'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('알림 a'));
      await tester.pumpAndSettle();
      expect(destination, 1);
      expect(service.unreadCount, 0);
      expect(find.byTooltip('알림, 읽지 않은 알림 0개'), findsOneWidget);
      await tester.tap(find.text('읽지 않음'));
      await tester.pumpAndSettle();
      expect(find.text('표시할 알림이 없어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
