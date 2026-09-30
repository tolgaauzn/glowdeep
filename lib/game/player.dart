import 'dart:math';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import '../data.dart';
import 'glowdeep_game.dart';

/// Lumora — oyuncunun taşıdığı son ışık kıvılcımı
class Lumora extends PositionComponent {
  Lumora(this.game);
  final GlowdeepGame game;
  double vy = 0;
  double flapT = 0;
  double blinkT = 0;
  double _prevScroll = 0;

  /// Sprite sheet: 1 satır × 6 kare kanat çırpma döngüsü (362×724 hücre)
  List<Sprite>? _frames;
  double _animT = 0;

  @override
  Future<void> onLoad() async {
    try {
      final data = await rootBundle.load('assets/images/player.png');
      final img = await decodeImageFromList(data.buffer.asUint8List());
      final sheet = SpriteSheet(image: img, srcSize: Vector2(362, 724));
      _frames = [for (var i = 0; i < 6; i++) sheet.getSprite(0, i)];
    } catch (e) {
      debugPrint('player.png yüklenemedi: $e');
    }
  }

  /// Kurdele izi — son pozisyonların ekran koordinatları
  final List<Offset> trail = [];
  static const maxTrail = 26;

  Skin get skin => skins.firstWhere((k) => k.id == game.save.selSkin,
      orElse: () => skins.first);

  @override
  void update(double dt) {
    flapT += dt;
    blinkT += dt;
    // basılıyken hızlı, serbestte yavaş çırpınma
    _animT += dt / (game.thrustHeld ? .055 : .13);
    // iz noktaları dünyayla birlikte geriye kayar
    final dx = game.scrollX - _prevScroll;
    _prevScroll = game.scrollX;
    for (var i = 0; i < trail.length; i++) {
      trail[i] = Offset(trail[i].dx - dx, trail[i].dy);
    }
    trail.removeWhere((p) => p.dx < -60);
    if (trail.isEmpty ||
        (Offset(position.x, position.y) - trail.last).distance > 7 * game.s) {
      trail.add(Offset(position.x - 8 * game.s, position.y));
      if (trail.length > maxTrail) trail.removeAt(0);
    }
  }

  @override
  void render(Canvas canvas) {
    final r = 13 * game.s;
    final inv = game.invulnT > 0;
    final alpha = inv ? .35 + .3 * sin(game.time * 30) : 1.0;

    // ---- kurdele izi (inci gibi sönümlenen) + skin'e özel iz dokusu ----
    for (var i = 1; i < trail.length; i++) {
      final t = i / trail.length;
      final p0 = trail[i - 1];
      final p1 = trail[i];
      canvas.drawLine(
        Offset(p0.dx - position.x, p0.dy - position.y),
        Offset(p1.dx - position.x, p1.dy - position.y),
        Paint()
          ..color = skin.glow.withValues(alpha: .28 * t * alpha)
          ..strokeWidth = (r * .9 * t + 1)
          ..strokeCap = StrokeCap.round,
      );
      if (i % 3 == 1) {
        _trailGlyph(
          canvas,
          Offset(p1.dx - position.x, p1.dy - position.y),
          t,
          atan2(p1.dy - p0.dy, p1.dx - p0.dx),
          alpha,
        );
      }
    }

    canvas.save();
    // hıza göre eğim + squash & stretch
    canvas.rotate((vy * 0.0005).clamp(-.38, .38));
    final stretch = (vy.abs() / (520 * game.s)).clamp(0.0, .16);
    canvas.scale(1 - stretch * .45, 1 + stretch);

    // iç parıltı
    canvas.drawCircle(
      Offset.zero,
      r * 2.4,
      Paint()
        ..shader = RadialGradient(colors: [
          skin.glow.withValues(alpha: .5 * alpha),
          skin.glow.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 2.4)),
    );

    final frames = _frames;
    if (frames != null) {
      // sprite karakter — skin rengi yumuşatılmış tint olarak uygulanır
      // (tam modulate koyulaştırır; beyazla karıştırınca renk canlı kalır)
      final tint = Color.lerp(Colors.white, skin.glow, .45)!;
      final f = frames[_animT.floor() % frames.length];
      f.render(
        canvas,
        position: Vector2(0, -r * .05),
        size: Vector2(r * 3.4, r * 6.8),
        anchor: Anchor.center,
        overridePaint: Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..colorFilter = ColorFilter.mode(tint, BlendMode.modulate),
      );
    } else {
      // fallback: prosedürel gövde
      final flap = sin(flapT * (game.thrustHeld ? 26 : 14)) * .55;
      final wingPaint = Paint()..color = skin.glow.withValues(alpha: .30 * alpha);
      for (final dir in [-1, 1]) {
        canvas.save();
        canvas.rotate(dir * .9 + flap * dir);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(-r * .7, 0), width: r * 1.6, height: r * .62),
          wingPaint,
        );
        canvas.restore();
      }
      canvas.drawCircle(
        Offset.zero,
        r * .72,
        Paint()
          ..shader = RadialGradient(
            colors: [skin.core, skin.glow],
            stops: const [.35, 1],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * .72)),
      );
      final eyeOpen = (blinkT % 3.6) < .14 ? .18 : 1.0;
      final eyeY = -r * .12 + (vy * .00006).clamp(-r * .1, r * .1);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(r * .28, eyeY), width: r * .32, height: r * .32 * eyeOpen),
        Paint()..color = const Color(0xFF201408).withValues(alpha: alpha),
      );
      if (eyeOpen > .5) {
        canvas.drawCircle(
          Offset(r * .33, eyeY - r * .04),
          r * .06,
          Paint()..color = Colors.white.withValues(alpha: alpha),
        );
      }
      canvas.drawCircle(
        Offset(-r * .18, -r * .2),
        r * .16,
        Paint()..color = Colors.white.withValues(alpha: .85 * alpha),
      );
    }
    canvas.restore();
  }

  /// Skin'e özel iz dokusu — her ışık kendi izini bırakır.
  /// [p] iz noktası (oyuncuya göreli), [t] 0..1 sönüm, [ang] izin yönü.
  void _trailGlyph(Canvas c, Offset p, double t, double ang, double alpha) {
    final s = game.s;
    final col = skin.glow.withValues(alpha: .5 * t * alpha);
    final fill = Paint()..color = col;
    final stroke = Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * s
      ..strokeCap = StrokeCap.round;
    switch (skin.id) {
      case 'ember': // sıçrayan köz tanecikleri
        final j = sin(t * 47 + p.dy) * 2.2 * s;
        c.drawCircle(p + Offset(0, j), 1.6 * s * t + .6, fill);
      case 'moon': // içi boş kabarcıklar
        c.drawCircle(p, 3.4 * s * t + 1, stroke);
      case 'violet': // dört köşeli yıldız parıltısı
        final r0 = 3.6 * s * t + 1;
        c.drawLine(p + Offset(0, -r0), p + Offset(0, r0), stroke);
        c.drawLine(p + Offset(-r0, 0), p + Offset(r0, 0), stroke);
      case 'dawn': // yönünde süzülen şafak taçyaprakları
        c.save();
        c.translate(p.dx, p.dy);
        c.rotate(ang + .5);
        c.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 7.5 * s * t + 1, height: 3 * s * t + .5),
          fill,
        );
        c.restore();
      case 'moss': // eğik minik yapraklar
        c.save();
        c.translate(p.dx, p.dy);
        c.rotate(ang - .6);
        final lt = 3.6 * s * t + .5;
        c.drawPath(
          Path()
            ..moveTo(-lt, 0)
            ..quadraticBezierTo(0, -lt, lt, 0)
            ..quadraticBezierTo(0, lt, -lt, 0)
            ..close(),
          fill,
        );
        c.restore();
      case 'stardust': // parlak çekirdek + artı parıltı
        c.drawCircle(p, 1.5 * s * t + .5, fill);
        final r0 = 4.6 * s * t + 1;
        c.drawLine(p + Offset(0, -r0), p + Offset(0, r0), stroke);
        c.drawLine(p + Offset(-r0, 0), p + Offset(r0, 0), stroke);
    }
  }
}
