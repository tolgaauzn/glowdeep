import 'dart:math';
import 'package:flutter/material.dart' hide Image;
import 'package:flame/components.dart';
import '../art.dart';
import 'glowdeep_game.dart';

/// Prosedürel mağara tüneli — 110px'lik dilimler halinde üretilir,
/// dilimler arası kosinüs interpolasyonu ile yumuşatılır.
class CaveTunnel extends Component {
  CaveTunnel(this.game);
  final GlowdeepGame game;
  static const segW = 110.0;

  final List<double> _cy = [];   // tünel merkezi
  final List<double> _hw = [];   // tünel yarı genişliği
  int _generated = 0;

  void reset() {
    _cy.clear();
    _hw.clear();
    _generated = 0;
    _ensure(game.size.x + segW * 4);
  }

  void _ensure(double worldX) {
    final r = game.rnd;
    while (_generated * segW < worldX) {
      final depth = _generated * segW / GlowdeepGame.meterPx;
      final h = game.size.y;
      // derinlikle daralan tünel
      final base = (205 - depth * 0.007).clamp(130.0, 205.0) * game.s;
      final hw = base * (0.92 + r.nextDouble() * 0.16);
      if (_cy.isEmpty) {
        _cy.add(h * 0.5);
      } else {
        var cy = _cy.last + (r.nextDouble() * 2 - 1) * h * 0.09;
        cy = cy.clamp(hw + 40 * game.s, h - hw - 40 * game.s);
        _cy.add(cy);
      }
      _hw.add(hw);
      _generated++;
    }
  }

  /// Konumdan üretilen deterministik "rastgele" — dekorlar kaymaz
  double _hash(double wx) {
    final i = (wx / 46).floor();
    final v = sin(i * 127.1) * 43758.5453;
    return v - v.floorToDouble();
  }

  void _gem(Canvas c, Offset p, double s, bool flip, Paint edge, Paint core) {
    final dir = flip ? -1.0 : 1.0;
    final path = Path()
      ..moveTo(p.dx - s * .6, p.dy)
      ..lineTo(p.dx, p.dy + s * dir)
      ..lineTo(p.dx + s * .6, p.dy)
      ..lineTo(p.dx + s * .2, p.dy - s * .3 * dir)
      ..lineTo(p.dx - s * .2, p.dy - s * .3 * dir)
      ..close();
    c.drawPath(path, edge);
    c.drawCircle(Offset(p.dx, p.dy + s * .3 * dir), s * .16, core);
  }

  double _lerp(List<double> a, double wx) {
    final i = (wx / segW).floor().clamp(0, a.length - 2);
    var t = (wx / segW) - i;
    t = t * t * (3 - 2 * t); // smoothstep
    return a[i] + (a[i + 1] - a[i]) * t;
  }

  double cAt(double wx) => _lerp(_cy, wx);
  double hAt(double wx) => _lerp(_hw, wx);
  double topAt(double wx) => cAt(wx) - hAt(wx);
  double bottomAt(double wx) => cAt(wx) + hAt(wx);

  @override
  void update(double dt) {
    _ensure(game.scrollX + game.size.x + segW * 6);
    // arkada kalan dilimleri buda
    final firstNeeded = (game.scrollX / segW).floor() - 2;
    if (firstNeeded > 0 && _cy.length > firstNeeded + 40) {
      // endeksleme baştan başladığı için sadece çok uzaksa kırp —
      // basitlik adına kırpmıyoruz (dilimler küçük double'lar)
    }
  }

  @override
  void render(Canvas canvas) {
    final zone = game.zone;
    final w = game.size.x;
    final h = game.size.y;
    const step = 14.0;

    final top = Path()..moveTo(-40, -40);
    final bot = Path()..moveTo(-40, h + 40);
    final topEdge = Path();
    final botEdge = Path();
    var first = true;
    for (double sx = -20; sx <= w + 20; sx += step) {
      final wx = game.scrollX + sx;
      final yt = topAt(wx);
      final yb = bottomAt(wx);
      top.lineTo(sx, yt);
      bot.lineTo(sx, yb);
      if (first) {
        topEdge.moveTo(sx, yt);
        botEdge.moveTo(sx, yb);
        first = false;
      } else {
        topEdge.lineTo(sx, yt);
        botEdge.lineTo(sx, yb);
      }
    }
    top..lineTo(w + 40, -40)..close();
    bot..lineTo(w + 40, h + 40)..close();

    final wallPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [zone.wall, Color.lerp(zone.wall, const Color(0xFF000000), .35)!, zone.wall],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(top, wallPaint);
    canvas.drawPath(bot, wallPaint);

    // wall.png — mat kaya dokusu, dünyaya kilitli tile'lanır.
    // Normal blend ile tam görünür çiz, üstüne bölge rengiyle tontla.
    final tex = Art.wall;
    if (tex != null) {
      const tile = 420.0;
      final off = -(game.scrollX % tile);
      final tp = Paint()..filterQuality = FilterQuality.medium;
      for (final path in [top, bot]) {
        canvas.save();
        canvas.clipPath(path);
        for (double x = off - tile; x < w + tile; x += tile) {
          for (double y = -tile; y < h + tile; y += tile) {
            canvas.drawImageRect(
              tex,
              Rect.fromLTWH(0, 0, tex.width.toDouble(), tex.height.toDouble()),
              Rect.fromLTWH(x, y, tile, tile),
              tp,
            );
          }
        }
        // dokuyu bölge rengine boyayan yarı saydam katman
        canvas.drawRect(
          Rect.fromLTWH(0, 0, w, h),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                zone.wall.withValues(alpha: .45),
                Color.lerp(zone.wall, const Color(0xFF000000), .35)!
                    .withValues(alpha: .55),
                zone.wall.withValues(alpha: .45),
              ],
            ).createShader(Rect.fromLTWH(0, 0, w, h)),
        );
        canvas.restore();
      }
    }

    // duvar kenarına iç gölge — tünel derinliği hissi
    final innerShade = Paint()
      ..color = const Color(0x5A000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16 * game.s
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * game.s);
    canvas.drawPath(topEdge, innerShade);
    canvas.drawPath(botEdge, innerShade);

    // kaya benekleri — duvar içine dağınık doku noktaları
    final speck = Paint()..color = zone.edge.withValues(alpha: .16);
    for (double sx = -20; sx <= w + 20; sx += 23) {
      final wx = game.scrollX + sx;
      final h2 = _hash(wx * 1.7 + 31);
      if (h2 < .2) {
        canvas.drawCircle(Offset(sx, topAt(wx) - (8 + h2 * 90) * game.s),
            (1 + h2 * 8) * game.s, speck);
      }
      if (h2 > .78) {
        canvas.drawCircle(Offset(sx, bottomAt(wx) + (8 + (h2 - .78) * 90) * game.s),
            (1 + (h2 - .78) * 10) * game.s, speck);
      }
    }

    // derin katman çizgisi — duvar içinde ikinci yumuşak damar
    final strata = Paint()
      ..color = zone.edge.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * game.s;
    final topStrata = Path();
    final botStrata = Path();
    var firstS = true;
    for (double sx = -20; sx <= w + 20; sx += step * 2) {
      final wx = game.scrollX + sx;
      final j = sin(wx * 0.06) * 12 * game.s;
      final yt = topAt(wx) - (46 * game.s + j);
      final yb = bottomAt(wx) + (46 * game.s - j);
      if (firstS) {
        topStrata.moveTo(sx, yt);
        botStrata.moveTo(sx, yb);
        firstS = false;
      } else {
        topStrata.lineTo(sx, yt);
        botStrata.lineTo(sx, yb);
      }
    }
    canvas.drawPath(topStrata, strata);
    canvas.drawPath(botStrata, strata);

    // duvar içi damar dokusu
    final vein = Paint()
      ..color = zone.edge.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * game.s;
    final topVein = Path();
    final botVein = Path();
    first = true;
    for (double sx = -20; sx <= w + 20; sx += step * 2) {
      final wx = game.scrollX + sx;
      final jitter = sin(wx * 0.11) * 9 * game.s;
      final yt = topAt(wx) - (16 + jitter);
      final yb = bottomAt(wx) + (16 - jitter);
      if (first) {
        topVein.moveTo(sx, yt);
        botVein.moveTo(sx, yb);
        first = false;
      } else {
        topVein.lineTo(sx, yt);
        botVein.lineTo(sx, yb);
      }
    }
    canvas.drawPath(topVein, vein);
    canvas.drawPath(botVein, vein);

    // duvara gömülü parlayan kristal dekoru — deterministik hash ile
    final deco = Paint()..color = zone.accent.withValues(alpha: .4);
    final decoCore = Paint()..color = Color.lerp(zone.accent, const Color(0xFFFFFFFF), .5)!.withValues(alpha: .5);
    for (double sx = -20; sx <= w + 20; sx += 46) {
      final wx = game.scrollX + sx;
      final h1 = _hash(wx);
      if (h1 < .16) {
        final yt = topAt(wx);
        final sz = (7 + h1 * 60) * game.s;
        _gem(canvas, Offset(sx, yt - 2), sz, true, deco, decoCore);
      }
      if (h1 > .5 && h1 < .66) {
        final yb = bottomAt(wx);
        final sz = (7 + (h1 - .5) * 60) * game.s;
        _gem(canvas, Offset(sx, yb + 2), sz, false, deco, decoCore);
      }
    }

    // parlayan kenar çizgisi
    final edge = Paint()
      ..color = zone.edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * game.s
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * game.s);
    canvas.drawPath(topEdge, edge);
    canvas.drawPath(botEdge, edge);
    final edgeCore = Paint()
      ..color = Color.lerp(zone.edge, const Color(0xFFFFFFFF), .45)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * game.s;
    canvas.drawPath(topEdge, edgeCore);
    canvas.drawPath(botEdge, edgeCore);
  }
}
