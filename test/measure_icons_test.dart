import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Her sheet hücresindeki gerçek içerik sınırlarını ölçer — alfa bbox.
/// Çıktıyı icons.dart'a _uiBoxes/_ranksBoxes olarak yapıştır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ikon bbox ölçümü', () async {
    for (final name in ['icons_ui', 'icons_ranks']) {
      final data = await rootBundle.load('assets/$name.png');
      final img = await decodeImageFromList(data.buffer.asUint8List());
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final px = bd!.buffer.asUint8List();
      final w = img.width;
      final h = img.height;
      final cw = w / 4;
      final ch = h / 4;
      final boxes = <String>[];
      for (var cell = 0; cell < 16; cell++) {
        final cx = (cell % 4) * cw;
        final cy = (cell ~/ 4) * ch;
        var minX = w, minY = h, maxX = 0, maxY = 0;
        for (var y = cy.floor(); y < (cy + ch).ceil(); y++) {
          for (var x = cx.floor(); x < (cx + cw).ceil(); x++) {
            final a = px[(y * w + x) * 4 + 3];
            if (a > 24) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }
        boxes.add(maxX > minX
            ? 'Rect.fromLTRB($minX, $minY, ${maxX + 1}, ${maxY + 1})'
            : 'Rect.fromLTWH($cx, $cy, $cw, $ch)');
      }
      debugPrint('=== $name ===');
      for (var i = 0; i < 16; i += 4) {
        debugPrint('  ${boxes.sublist(i, i + 4).join(',\n  ')},');
      }
    }
  });
}
