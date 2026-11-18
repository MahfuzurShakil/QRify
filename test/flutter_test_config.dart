import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the real Roboto + Material Icons fonts that ship with the Flutter SDK,
/// so widget tests lay text out like a real Android phone instead of the wide
/// square "Ahem" test font (which reports overflows that never happen on device).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final dir = Directory('$root/bin/cache/artifacts/material_fonts');
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        final file = File('${dir.path}/$f');
        if (file.existsSync()) {
          final bytes = file.readAsBytesSync();
          loader.addFont(Future.value(ByteData.sublistView(bytes)));
        }
      }
      await loader.load();
    }

    await load('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Black.ttf',
      'Roboto-Light.ttf',
    ]);
    await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  }
  await testMain();
}
