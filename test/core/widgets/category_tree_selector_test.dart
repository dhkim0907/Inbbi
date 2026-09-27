import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/core/widgets/category_tree_selector.dart';

void main() {
  const categories = [
    CategoryNode(
      id: 'school',
      label: '학교',
      children: [
        CategoryNode(id: 'academic', label: '학사'),
        CategoryNode(id: 'scholarship', label: '장학'),
      ],
    ),
  ];

  testWidgets('선택된 하위 카테고리의 경로를 펼치고 선택을 전달한다', (tester) async {
    CategoryNode? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryTreeSelector(
            categories: categories,
            selectedId: 'academic',
            onSelected: (node) => selected = node,
          ),
        ),
      ),
    );

    expect(find.text('학사'), findsOneWidget);
    await tester.tap(find.text('장학'));
    expect(selected?.id, 'scholarship');

    await tester.tap(find.byTooltip('학교 접기'));
    await tester.pump();
    expect(find.text('학사'), findsNothing);
  });

  for (final width in [390.0, 840.0]) {
    testWidgets('너비 $width에서 여러 카테고리를 선택하고 해제한다', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Set<String> selected = {'academic'};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => CategoryTreeSelector(
                categories: categories,
                selectedIds: selected,
                onSelectionChanged: (ids) => setState(() => selected = ids),
              ),
            ),
          ),
        ),
      );

      expect(find.text('학사'), findsOneWidget);
      await tester.tap(find.text('장학'));
      await tester.pump();
      expect(selected, {'academic', 'scholarship'});
      await tester.tap(find.text('학사'));
      await tester.pump();
      expect(selected, {'scholarship'});
      expect(tester.takeException(), isNull);
    });
  }
}
