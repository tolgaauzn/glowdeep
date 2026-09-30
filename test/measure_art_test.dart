import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// coin.png (6×1) ve mobs.png (2×2) hücrelerinin alfa bbox'larını ölçer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('art bbox ölçümü', () async {
    for (final e in [
      ('coin', 6, 1),
      ('mobs', 2, 2),
    ]) {
      final data = await rootBundle.load('assets/${e.$1}.png');
      final img = await decodeImageFromList(data.buffer.asUint8List());
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final px = bd!.buffer.asUint8List();
      final w = img.width, h = img.height;
      final cols = e.$2, rows = e.$3;
      final cw = w / cols, ch = h / rows;
      debugPrint('=== ${e.$1}: ${w}x$h — hücre ${cw}x$ch ===');
      for (var cell = 0; cell < cols * rows; cell++) {
        final cx = (cell % cols) * cw;
        final cy = (cell ~/ cols) * ch;
        var minX = w, minY = h, maxX = 0, maxY = 0;
        for (var y = cy.floor(); y < (cy + ch).ceil(); y++) {
          for (var x = cx.floor(); x < (cx + cw).ceil(); x++) {
            if (px[(y * w + x) * 4 + 3] > 24) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }
        debugPrint('cell$cell: ${maxX > minX ? "Rect.fromLTRB($minX,$minY,${maxX + 1},${maxY + 1})" : "BOŞ"}');
      }
    }
  });
}
