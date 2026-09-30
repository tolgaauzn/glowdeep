import 'dart:math';
import 'package:flutter/material.dart' hide Image;
import 'package:flame/components.dart';

/// Hafif parçacık sistemi — toplama, kuyruk, patlama
class Particle extends Component {
  Particle({
    required this.pos,
    required this.vel,
    required this.life,
    required this.color,
    required this.size,
    this.drag = .98,
    this.grow = 0,
  }) : maxLife = life;
  Vector2 pos;
  Vector2 vel;
  double life;
  final double maxLife;
  Color color;
  double size;
  double drag;
  double grow;
  double age = 0;

  @override
  void update(double dt) {
    age += dt;
    vel.scale(pow(drag, dt * 60).toDouble());
    pos += vel * dt;
    if (age >= maxLife) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = 1 - age / maxLife;
    canvas.drawCircle(
      Offset(pos.x, pos.y),
      (size + grow * age) * t.clamp(0.2, 1),
      Paint()
        ..color = color.withValues(alpha: t * .9)
        ..blendMode = BlendMode.plus,
    );
  }
}

/// Havada yüzen skor yazısı
class FloatText extends Component {
  FloatText(this.pos, this.text, this.color, {this.big = false, this.dur = 1.1});
  Vector2 pos;
  final String text;
  final Color color;
  final bool big;
  final double dur;
  double age = 0;

  @override
  void update(double dt) {
    age += dt;
    pos.y -= 46 * dt;
    if (age >= dur) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = 1 - age / dur;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: t),
          fontSize: big ? 26 : 15,
          fontWeight: FontWeight.w800,
          letterSpacing: big ? 4 : 1,
          shadows: [Shadow(color: color.withValues(alpha: t * .8), blurRadius: 12)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.x - tp.width / 2, pos.y));
  }
}

/// Işık Darbesi — genişleyen şok halkası (çift dokunuş skill'i)
class PulseWave extends Component {
  PulseWave({required this.center, required this.maxR, required this.color});
  final Vector2 center;
  final double maxR;
  final Color color;
  double age = 0;
  static const double dur = .38;

  @override
  void update(double dt) {
    age += dt;
    if (age >= dur) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = age / dur;
    final ease = 1 - pow(1 - t, 3).toDouble();
    final c = Offset(center.x, center.y);
    canvas.drawCircle(
      c,
      maxR * ease,
      Paint()
        ..color = color.withValues(alpha: .14 * (1 - t))
        ..blendMode = BlendMode.plus,
    );
    canvas.drawCircle(
      c,
      maxR * ease,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * (1 - t) + 1.5
        ..color = color.withValues(alpha: .85 * (1 - t))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..blendMode = BlendMode.plus,
    );
  }
}

/// Ekran sarsıntısı yardımcı sınıfı — GlowdeepGame kullanır
class Shake {
  double t = 0;
  double amp = 0;
  final _r = Random();
  void add(double a) {
    amp = max(amp, a);
    t = .4;
  }

  Offset offset(double dt) {
    if (t <= 0) return Offset.zero;
    t -= dt;
    if (t <= 0) {
      amp = 0;
      return Offset.zero;
    }
    final k = amp * (t / .4);
    return Offset((_r.nextDouble() * 2 - 1) * k, (_r.nextDouble() * 2 - 1) * k);
  }
}
