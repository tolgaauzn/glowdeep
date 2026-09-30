import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';

/// Üretilmiş sprite asset'leri — coin animasyonu, canavarlar, duvar dokusu.
/// `main()` içinde `Art.load()` çağrılır; bir dosya yüklenemezse ilgili
/// entity prosedürel fallback çizimine döner.
class Art {
  static ui.Image? coin; // 6×1 animasyon satırı
  static ui.Image? mobs; // 2×2: güve, yarasa, kristal, denizanası
  static ui.Image? wall; // tileable kaya dokusu

  /// Her hücrenin gerçek içerik sınırları (alfa bbox)
  static List<Rect> coinFrames = [];
  static List<Rect> mobCells = [];

  /// mobCells indeksleri
  static const mobMoth = 0;
  static const mobBat = 1;
  static const mobCrystal = 2;
  static const mobJelly = 3;

  static Future<void> load() async {
    coin = await _img('assets/coin.png');
    mobs = await _img('assets/mobs.png');
    wall = await _img('assets/wall.png');
    if (coin != null) coinFrames = await _boxes(coin!, 6, 1);
    if (mobs != null) mobCells = await _boxes(mobs!, 2, 2);
  }

  static Future<ui.Image?> _img(String path) async {
    try {
      final d = await rootBundle.load(path);
      return await decodeImageFromList(d.buffer.asUint8List());
    } catch (e) {
      debugPrint('$path yüklenemedi: $e');
      return null;
    }
  }

  /// Izgara hücrelerinin alfa içerik sınırlarını ölçer —
  /// AI sheet'leri hücre ortalı olmadığı için eşit dilimleme kaydırır.
  static Future<List<Rect>> _boxes(ui.Image img, int cols, int rows) async {
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final px = bd!.buffer.asUint8List();
    final w = img.width, h = img.height;
    final cw = w / cols, ch = h / rows;
    final out = <Rect>[];
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
      out.add(maxX > minX
          ? Rect.fromLTRB(
              minX.toDouble(), minY.toDouble(), maxX + 1.0, maxY + 1.0)
          : Rect.fromLTWH(cx, cy, cw, ch));
    }
    return out;
  }

  /// [src] bölgesini [size] çaplı kareye contain-fit çizer (merkezde).
  /// Çağıran taraf canvas'ı sprite merkezine translate etmiş olmalı.
  static void drawCell(
      Canvas canvas, ui.Image img, Rect src, double size, Paint paint) {
    final sc = min(size / src.width, size / src.height);
    canvas.drawImageRect(
      img,
      src,
      Rect.fromCenter(
          center: Offset.zero,
          width: src.width * sc,
          height: src.height * sc),
      paint..filterQuality = FilterQuality.medium,
    );
  }
}
