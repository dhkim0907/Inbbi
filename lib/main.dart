import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final fontLoader = FontLoader('NotoSansKR');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    fontLoader.addFont(rootBundle.load('assets/fonts/NotoSansKR-$weight.ttf'));
  }
  await fontLoader.load();

  runApp(const InbbiApp());
}
