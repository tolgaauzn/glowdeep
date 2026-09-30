import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';
import 'data.dart';

/// İkon indeksleri — 4×4 ızgaralı sprite sheet'lerden dilimlenir.
///
/// `assets/icons_ui.png` (0-15):
///   0 play, 1 replay, 2 pause, 3 gear,
///   4 back, 5 share, 6 quests, 7 upgrade,
///   8 skin, 9 book, 10 lum, 11 depth,
///   12 flame, 13 shield, 14 note, 15 vibe
///
/// `assets/icons_ranks.png` (100-115):
///   100-105 rütbe madalyonları (bronz→prizma),
///   106 trophy, 107 torch, 108 flag, 109 bolt,
///   110 wings, 111 magnet, 112 check, 113 lock, 114 gift, 115 orb
class GI {
  static const play = 0;
  static const replay = 1;
  static const pause = 2;
  static const gear = 3;
  static const back = 4;
  static const share = 5;
  static const quests = 6;
  static const upgrade = 7;
  static const skin = 8;
  static const book = 9;
  static const lum = 10;
  static const depth = 11;
  static const flame = 12;
  static const shield = 13;
  static const note = 14;
  static const vibe = 15;

  static const rank0 = 100; // bronz köz
  static const rank1 = 101; // gümüş ay
  static const rank2 = 102; // altın güneş
  static const rank3 = 103; // teal kristal
  static const rank4 = 104; // mor yıldız
  static const rank5 = 105; // prizmatik efsane
  static const trophy = 106;
  static const torch = 107;
  static const flag = 108;
  static const bolt = 109;
  static const wings = 110;
  static const magnet = 111;
  static const check = 112;
  static const lock = 113;
  static const gift = 114;
  static const orb = 115;
}

/// Sheet'leri uygulama açılışında yükler — `main()` içinde çağrılır.
class GameIcons {
  static ui.Image? _ui;
  static ui.Image? _ranks;

  static Future<void> load() async {
    try {
      final d = await rootBundle.load('assets/icons_ui.png');
      _ui = await decodeImageFromList(d.buffer.asUint8List());
    } catch (e) {
      debugPrint('icons_ui.png yüklenemedi: $e');
    }
    try {
      final d = await rootBundle.load('assets/icons_ranks.png');
      _ranks = await decodeImageFromList(d.buffer.asUint8List());
    } catch (e) {
      debugPrint('icons_ranks.png yüklenemedi: $e');
    }
  }

  /// Toplam metreye göre rütbe madalyonu indeksi (7 rütbe → 6 madalyon)
  static int rankBadge(int totalMeters) {
    var i = 0;
    for (var k = 0; k < ranks.length; k++) {
      if (totalMeters >= ranks[k].meters) i = k;
    }
    return GI.rank0 + i.clamp(0, 5);
  }
}

/// Sheet'ten dilimlenmiş oyun ikonu — [idx] 0-15 UI sheet'i, 100-115 rank sheet'i.
class GIcon extends StatelessWidget {
  const GIcon(this.idx,
      {super.key, this.size = 20, this.opacity = 1, this.tint, this.flip = false});

  final int idx;
  final double size;

  /// 0-1 arası saydamlık (kapalı/pasif durumlar için)
  final double opacity;

  /// Verilirse ikon bu rengin silüeti olur (altın buton üstü koyu ikon gibi)
  final Color? tint;

  /// Yatay ayna — back ikonundan sağ ok türetmek için
  final bool flip;

  @override
  Widget build(BuildContext context) {
    final ranked = idx >= 100;
    final img = ranked ? GameIcons._ranks : GameIcons._ui;
    if (img == null) return SizedBox.square(dimension: size);
    return CustomPaint(
      size: Size.square(size),
      painter: _GIconPainter(
          img, idx % 100, opacity, tint, flip,
          (ranked ? _ranksBoxes : _uiBoxes)[idx % 100]),
    );
  }
}

/// Ölçülmüş içerik sınırları (alfa bbox) — ızgara kaymasından bağımsız
/// her ikon tam merkezli ve maksimum boyutta çizilir.
const _uiBoxes = [
  Rect.fromLTRB(56, 73, 278, 288),
  Rect.fromLTRB(362, 64, 597, 292),
  Rect.fromLTRB(670, 69, 885, 291),
  Rect.fromLTRB(977, 65, 1214, 290),
  Rect.fromLTRB(43, 378, 300, 593),
  Rect.fromLTRB(353, 394, 596, 599),
  Rect.fromLTRB(663, 364, 904, 609),
  Rect.fromLTRB(1002, 362, 1199, 608),
  Rect.fromLTRB(36, 634, 301, 918),
  Rect.fromLTRB(349, 658, 610, 897),
  Rect.fromLTRB(669, 671, 898, 893),
  Rect.fromLTRB(994, 674, 1191, 890),
  Rect.fromLTRB(40, 963, 293, 1188),
  Rect.fromLTRB(359, 948, 601, 1193),
  Rect.fromLTRB(665, 956, 910, 1184),
  Rect.fromLTRB(975, 955, 1222, 1188),
];

const _ranksBoxes = [
  Rect.fromLTRB(27, 45, 314, 314),
  Rect.fromLTRB(313, 42, 622, 314),
  Rect.fromLTRB(636, 42, 933, 314),
  Rect.fromLTRB(945, 44, 1236, 314),
  Rect.fromLTRB(25, 313, 314, 616),
  Rect.fromLTRB(313, 313, 627, 627),
  Rect.fromLTRB(627, 313, 930, 623),
  Rect.fromLTRB(950, 313, 1215, 627),
  Rect.fromLTRB(24, 645, 313, 941),
  Rect.fromLTRB(335, 627, 616, 941),
  Rect.fromLTRB(628, 642, 940, 941),
  Rect.fromLTRB(957, 627, 1227, 941),
  Rect.fromLTRB(26, 940, 314, 1189),
  Rect.fromLTRB(313, 940, 623, 1196),
  Rect.fromLTRB(636, 940, 927, 1202),
  Rect.fromLTRB(944, 940, 1236, 1195),
];

class _GIconPainter extends CustomPainter {
  _GIconPainter(this.img, this.cell, this.opacity, this.tint, this.flip, this.src);
  final ui.Image img;
  final int cell;
  final double opacity;
  final Color? tint;
  final bool flip;
  final Rect src;

  @override
  void paint(Canvas canvas, Size size) {
    // contain-fit: ikonun gerçek sınırlarını kare alana orantılı sığdır
    final scale =
        (size.width / src.width).clamp(0.0, size.height / src.height);
    final dw = src.width * scale;
    final dh = src.height * scale;
    final dst = Rect.fromLTWH(
        (size.width - dw) / 2, (size.height - dh) / 2, dw, dh);
    if (flip) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(
      img,
      src,
      dst,
      Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..colorFilter =
            tint == null ? null : ColorFilter.mode(tint!, BlendMode.srcIn)
        ..filterQuality = FilterQuality.medium,
    );
    if (flip) canvas.restore();
  }

  @override
  bool shouldRepaint(_GIconPainter o) =>
      o.img != img ||
      o.cell != cell ||
      o.opacity != opacity ||
      o.tint != tint ||
      o.flip != flip ||
      o.src != src;
}
