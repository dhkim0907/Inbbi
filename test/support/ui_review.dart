import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadReviewFonts() async {
  final loader = FontLoader('NotoSansKR');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(rootBundle.load('assets/fonts/NotoSansKR-$weight.ttf'));
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons');
  icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<void> captureReview(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  if (Platform.environment['INBBI_UI_REVIEW'] != '1') return;
  final previousShadows = debugDisableShadows;
  debugDisableShadows = false;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  void repaint(RenderObject object) {
    object.markNeedsPaint();
    object.visitChildren(repaint);
  }

  repaint(boundary);
  await tester.pump();
  try {
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/ui_review/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  } finally {
    debugDisableShadows = previousShadows;
    repaint(boundary);
    await tester.pump();
  }
}
