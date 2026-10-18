import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/features/settings/data_collection_preferences.dart';
import 'package:inbbi/features/settings/data_collection_settings_card.dart';

class _MemoryStorage implements DataCollectionPreferenceStorage {
  Set<DataSource>? saved;

  @override
  Future<Set<DataSource>?> load() async => saved;

  @override
  Future<void> save(Set<DataSource> sources) async => saved = Set.of(sources);
}

void main() {
  for (final width in [390.0, 840.0]) {
    testWidgets('너비 $width에서 수집 대상을 선택한다', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = _MemoryStorage();
      final preferences = DataCollectionPreferences(storage);
      addTearDown(preferences.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DataCollectionSettingsCard(preferences: preferences),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('인하대 포털'), findsOneWidget);
      await tester.tap(find.text('인하대 포털'));
      await tester.pump();
      expect(storage.saved, isNot(contains(DataSource.portal)));
      expect(tester.takeException(), isNull);
    });
  }
}
