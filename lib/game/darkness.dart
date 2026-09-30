import 'dart:math';
import 'package:flutter/material.dart' hide Image;
import 'package:flame/components.dart';
import '../data.dart';
import 'entities.dart';
import 'glowdeep_game.dart';

/// Ön plan silüetleri — kameraya çok yakın geçen karanlık kayalar
/// (karanlık perdenin ÜSTÜNDE çizilir → derinlik illüzyonu)
class ForegroundRocks extends Component {
  ForegroundRocks(this.game);
  final GlowdeepGame game;

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;
    const gap = 640.0;
    const par = 1.55;
    final paint = Paint()..color = const Color(0xF002040A);
    final start = ((game.scrollX * par) / gap).floor() - 1;
    for (var i = start; i < start + (w / gap).ceil() + 3; i++) {
      final rx = i * gap - game.scrollX * par;
      final hh = _h(i);
      if (hh < .55) continue; // her iki slotta bir
      final top = hh < .78;
      final rockH = h * (.18 + (hh - .55) * .5);
      final rockW = 90 + hh * 160;
      final path = Path();
      if (top) {
        path
          ..moveTo(rx - rockW * .5, -10)
          ..quadraticBezierTo(rx, rockH * .5, rx + rockW * .1, rockH)
          ..quadraticBezierTo(rx + rockW * .45, rockH * .55, rx + rockW * .5, -10)
          ..close();
      } else {
        path
          ..moveTo(rx - rockW * .5, h + 10)
          ..quadraticBezierTo(rx, h - rockH * .5, rx + rockW * .1, h - rockH)
          ..quadraticBezierTo(rx + rockW * .45, h - rockH * .55, rx + rockW * .5, h + 10)
          ..close();
      }
      canvas.drawPath(path, paint);
    }
  }

  double _h(int i) {
    final v = sin(i * 91.7) * 24634.6345;
    return v - v.floorToDouble();
  }
}

/// Karanlık perdesi — tüm sahneyi karartır, oyuncunun ışık halkası
/// ve küçük ışık kaynakları etrafında delik açar.
class DarknessVeil extends Component {
  DarknessVeil(this.game);
  final GlowdeepGame game;

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;
    final rect = Rect.fromLTWH(0, 0, w, h);

    canvas.saveLayer(rect, Paint());
    // karanlık
    canvas.drawRect(rect, Paint()..color = const Color(0xF2030510));
    // oyuncunun ışığı — hafif alev titremesi + mega boost
    final p = game.playerPos;
    final flicker = 1 + .035 * sin(game.time * 9) + .02 * sin(game.time * 23);
    final lr = game.lightR * flicker * (game.lightBoostT > 0 ? 1.55 : 1);
    _punch(canvas, p, lr * 1.15);
    canvas.restore();

    // oyuncu etrafında ince ışık halkası çizgisi
    canvas.drawCircle(
      p,
      lr * 1.02,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = game.zone.accent.withValues(alpha: .12),
    );
  }

  void _punch(Canvas c, Offset at, double r) {
    c.drawCircle(
      at,
      r,
      Paint()
        ..blendMode = BlendMode.clear
        ..shader = RadialGradient(
          colors: const [Color(0xFFFFFFFF), Color(0xCCFFFFFF), Color(0x00FFFFFF)],
          stops: const [0, .55, 1],
        ).createShader(Rect.fromCircle(center: at, radius: r)),
    );
  }
}

/// Karanlığın ÜSTÜNDE çizilen neon parlama katmanı —
/// Lumlar ve tehlike gözleri karanlıkta bile görünür.
class GlowPass extends Component {
  GlowPass(this.game);
  final GlowdeepGame game;
  double t = 0;
  final _r = Random(3);
  late final List<Offset> motes;

  @override
  Future<void> onLoad() async {
    motes = List.generate(26, (_) => Offset(_r.nextDouble(), _r.nextDouble()));
  }

  @override
  void update(double dt) => t += dt;

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;
    final plus = Paint()..blendMode = BlendMode.plus;

    // sürüklenen ışık tozları (derinlik hissi + bölge karakteri)
    final zi = ZoneBlend.indexAt(game.depth);
    for (var i = 0; i < motes.length; i++) {
      final m = motes[i];
      final mx = (m.dx * w - game.scrollX * .1) % w;
      final x = mx < 0 ? mx + w : mx;
      double y;
      double alpha;
      if (zi == 3) {
        // Küller Vadisi — yükselen közler
        y = h - ((m.dy * h + t * (30 + (i % 5) * 14)) % h);
        alpha = .16 + .08 * sin(t * 3 + i);
      } else {
        y = (m.dy * h + sin(t * .5 + m.dx * 20) * 12) % h;
        alpha = zi == 4
            ? .10 + .18 * (sin(t * 2.2 + i * 1.7) * .5 + .5) // Göğün Dibi — yıldız parıltısı
            : .10;
      }
      canvas.drawCircle(
        Offset(x, y < 0 ? y + h : y),
        (zi == 3 ? 2.0 : 1.6) * game.s,
        plus..shader = null
          ..color = (zi == 3 ? const Color(0xFFFF8A3D) : game.zone.accent)
              .withValues(alpha: alpha.clamp(0, .3)),
      );
    }

    // Lum küreleri karanlıkta parlar
    for (final e in game.entities) {
      if (e is Orb && !e.dead) {
        final glowR = e.radius * 3.2;
        canvas.drawCircle(
          Offset(e.px, e.position.y),
          glowR,
          plus
            ..shader = RadialGradient(colors: [
              const Color(0xCCFFD66B),
              const Color(0x33FFB840),
              const Color(0x00FFB840),
            ], stops: const [0, .5, 1]).createShader(
                Rect.fromCircle(center: Offset(e.px, e.position.y), radius: glowR)),
        );
      } else if (e is Moth && !e.dead) {
        // gölge güvesinin gözleri
        for (final dx in [-5.0, 5.0]) {
          canvas.drawCircle(
            Offset(e.px + dx * game.s, e.position.y - 3 * game.s),
            2.4 * game.s,
            plus..shader = null..color = game.zone.accent.withValues(alpha: .8),
          );
        }
      } else if (e is Crystal && !e.dead) {
        // kristal uçlarının fısıldayan parıltısı
        canvas.drawCircle(
          Offset(e.px, e.position.y),
          3.2 * game.s,
          plus..shader = null..color = game.zone.accent.withValues(alpha: .55),
        );
      } else if (e is Stalactite && !e.dead && !e.falling) {
        // uyarı — düşmeden önce kırmızı yanıp sönen nokta
        final blink = .35 + .45 * (sin(t * 14) * .5 + .5);
        canvas.drawCircle(
          Offset(e.px, e.position.y + e.radius * 1.4),
          4.5 * game.s,
          plus..shader = null..color = const Color(0xFFFF5040).withValues(alpha: blink),
        );
      } else if (e is Hunter && !e.dead) {
        canvas.drawCircle(
          Offset(e.px + e.radius * .15, e.position.y - e.radius * .2),
          4 * game.s,
          plus..shader = null..color = const Color(0xFFFF4040).withValues(alpha: .85),
        );
      } else if (e is MegaOrb && !e.dead) {
        final glowR = e.radius * 3.6;
        canvas.drawCircle(
          Offset(e.px, e.position.y),
          glowR,
          plus
            ..shader = RadialGradient(colors: const [
              Color(0xCC9FE8FF),
              Color(0x33B78BFF),
              Color(0x00B78BFF),
            ], stops: const [0, .5, 1]).createShader(
                Rect.fromCircle(center: Offset(e.px, e.position.y), radius: glowR)),
        );
      }
    }

    // hız çizgileri — hız arttıkça belirginleşir
    final spd = (game.speed / (340 * game.s)).clamp(0.0, 1.0);
    if (spd > .55 && game.phase == Phase.playing) {
      final a = (spd - .55) * .9;
      final linePaint = Paint()
        ..blendMode = BlendMode.plus
        ..color = Colors.white.withValues(alpha: a * .12)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 10; i++) {
        final seed = i * 977.0;
        final y = ((seed + t * 97 * i) % 1).abs() * h;
        final lx = (w - ((t * (900 + i * 60) + seed * 40) % (w + 300)));
        canvas.drawLine(Offset(lx, y), Offset(lx + 60 + spd * 80, y), linePaint);
      }
    }

    // oyuncunun sıcak çekirdek parıltısı + kombo halkası
    if (game.phase != Phase.dead) {
      final p = game.playerPos;
      final r = 46 * game.s;
      canvas.drawCircle(
        p,
        r,
        plus
          ..shader = RadialGradient(colors: [
            game.player.skin.glow.withValues(alpha: .5),
            const Color(0x00000000),
          ]).createShader(Rect.fromCircle(center: p, radius: r)),
      );
      // kombo süresini gösteren solan halka
      if (game.combo > 0 && game.comboT > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: p, radius: 26 * game.s),
          -pi / 2,
          (game.comboT / 1.6) * pi * 2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6 * game.s
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFFFFD66B)
                .withValues(alpha: (.35 + .3 * sin(t * 8)).clamp(0, 1)),
        );
      }
    }
  }
}
