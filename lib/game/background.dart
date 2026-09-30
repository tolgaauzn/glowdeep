import 'dart:math';
import 'package:flutter/material.dart' hide Image;
import 'package:flame/components.dart';
import 'glowdeep_game.dart';

/// Paralaks mağara derinliği: degrade gökyüzü + uzak silüet katmanları
class CaveBackground extends Component {
  CaveBackground(this.game);
  final GlowdeepGame game;
  final _r = Random(99);
  late List<List<_Pillar>> _layers;

  @override
  Future<void> onLoad() async {
    _layers = [
      _genLayer(0.15, 340, .16),
      _genLayer(0.32, 250, .24),
      _genLayer(0.55, 180, .34),
    ];
  }

  List<_Pillar> _genLayer(double par, double gap, double hFrac) {
    // 60 sütun yeter; modulo ile sonsuz tekrarlanır
    return List.generate(
        60,
        (i) => _Pillar(
              x: i * gap + _r.nextDouble() * gap * .5,
              w: gap * (.5 + _r.nextDouble() * .5),
              hFrac: hFrac * (.6 + _r.nextDouble() * .8),
              top: _r.nextBool(),
              par: par,
            ));
  }

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;
    final z = game.zone;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [z.bgTop, z.bgBottom],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // havada süzülen ışık tozları — paralaks + hafif salınım
    final dustPaint = Paint()..color = z.accent.withValues(alpha: .10);
    final dr = Random(7);
    final loopW = w * 1.6;
    for (var i = 0; i < 42; i++) {
      final dx = dr.nextDouble() * loopW;
      final dy = dr.nextDouble() * h;
      final r = (0.8 + dr.nextDouble() * 2.2) * game.s;
      var sx = (dx - game.scrollX * .45) % loopW;
      if (sx < -10) sx += loopW;
      if (sx > w + 10) continue;
      final sy = dy + sin(game.time * .7 + i * 1.7) * 7 * game.s;
      canvas.drawCircle(Offset(sx, sy), r, dustPaint);
    }

    for (final layer in _layers) {
      for (final p in layer) {
        final loopW = 60 * (p.par == .15 ? 340.0 : p.par == .32 ? 250.0 : 180.0);
        var sx = (p.x - game.scrollX * p.par) % loopW;
        if (sx < -p.w) sx += loopW;
        if (sx > w + p.w) continue;
        final ph = h * p.hFrac;
        final paint = Paint()
          ..color = Color.lerp(z.wall, const Color(0xFF000000), .55)!
              .withValues(alpha: .5);
        final rect = p.top
            ? Rect.fromLTWH(sx, -10, p.w, ph)
            : Rect.fromLTWH(sx, h - ph + 10, p.w, ph);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(p.w * .3)),
          paint,
        );
      }
    }
  }
}

class _Pillar {
  final double x, w, hFrac, par;
  final bool top;
  _Pillar({required this.x, required this.w, required this.hFrac, required this.top, required this.par});
}
