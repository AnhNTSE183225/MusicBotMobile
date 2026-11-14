import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicbot_mobile/components/musicbot_logo.dart';

void main() {
  test('Generate Android mipmap launcher icons and splash assets', () async {
    const targets = <String, int>{
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
      'assets/app_icon_512.png': 512,
    };

    for (final entry in targets.entries) {
      final size = entry.value.toDouble();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

      const painter = MusicBotLogoPainter(withAppIconBackground: true);
      painter.paint(canvas, Size(size, size));

      final picture = recorder.endRecording();
      final image = await picture.toImage(entry.value, entry.value);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final file = File(entry.key);
        if (!file.parent.existsSync()) {
          file.parent.createSync(recursive: true);
        }
        await file.writeAsBytes(byteData.buffer.asUint8List());
        // ignore: avoid_print
        print('Generated ${entry.key} (${entry.value}x${entry.value})');
      }
    }
  });
}
