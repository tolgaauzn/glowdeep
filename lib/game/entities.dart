import 'dart:math';
import 'package:flutter/material.dart' hide Image;
import 'package:flame/components.dart';
import '../art.dart';
import 'glowdeep_game.dart';

abstract class GameEntity extends PositionComponent {
  GameEntity(this.game, this.worldX);
  final GlowdeepGame game;
  double worldX;
  double radius = 10;
  bool dead = false;
  bool nearChecked = false;
  double minDist = 99999;

  double get px => worldX - game.scrollX;

  @override
  void update(double dt) {
    position.x = px;
    if (px < -160) dead = true;
  }
}

/// Lum — dönen kristal ışık parçası
class Orb extends GameEntity {
  Orb(super.game, super.wx, this.baseY) {
    radius = 9 * game.s;
    position.y = baseY;
    phase = game.rnd.nextDouble() * pi * 2;
  }
  double baseY;
  double phase = 0;
  double t = 0;
  double vx = 0, vy = 0;
  bool magnetOn = false;

  @override
  void update(double dt) {
    super.update(dt);
    t += dt;
    if (!magnetOn) {
      position.y = baseY + sin(t * 3 + phase) * 6 * game.s;
    } else {
      final dx = game.playerScreenX - position.x;
      final dy = game.playerPos.dy - position.y;
      vx += dx * 14 * dt;
      vy += dy * 14 * dt;
      position.x += vx * dt;
      position.y += vy * dt;
      worldX = position.x + game.scrollX;
    }
  }

  @override
  void render(Canvas canvas) {
    final r = radius;
    // coin.png — 6 karelik parıltı döngüsü
    final img = Art.coin;
    if (img != null && Art.coinFrames.length >= 6) {
      final frame = (t * 10 + phase) % 6;
      Art.drawCell(
          canvas, img, Art.coinFrames[frame.floor()], r * 2.6, Paint());
      return;
    }
    canvas.save();
    canvas.rotate(t * 1.6 + phase);
    // dönen kristal (oktahedron)
    final gem = Path()
      ..moveTo(0, -r)
      ..lineTo(r * .62, 0)
      ..lineTo(0, r)
      ..lineTo(-r * .62, 0)
      ..close();
    canvas.drawPath(
      gem,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Color(0xFFFFF6D0), Color(0xFFFFB840)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    canvas.drawPath(
      gem,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFFFFCF0),
    );
    // iç kırık çizgisi
    canvas.drawLine(
      Offset(0, -r * .7),
      Offset(0, r * .7),
      Paint()..color = const Color(0x88FFF9E6)..strokeWidth = 1,
    );
    canvas.restore();
  }
}

/// Aurora Çekirdeği — nadir, büyük ödül + geçici mega ışık
class MegaOrb extends Orb {
  MegaOrb(super.game, super.wx, super.baseY) {
    radius = 17 * game.s;
  }

  @override
  void render(Canvas canvas) {
    final r = radius * (1 + sin(t * 4) * .07);
    canvas.save();
    canvas.rotate(-t * .9);
    final gem = Path()
      ..moveTo(0, -r)
      ..lineTo(r * .7, -r * .3)
      ..lineTo(r * .7, r * .35)
      ..lineTo(0, r)
      ..lineTo(-r * .7, r * .35)
      ..lineTo(-r * .7, -r * .3)
      ..close();
    canvas.drawPath(
      gem,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFF7FF5FF), Color(0xFFB78BFF)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    canvas.drawPath(
      gem,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white,
    );
    canvas.restore();
  }
}

/// Gölge Kristali — duvardan içeri uzayan sivri tehlike
class Crystal extends GameEntity {
  Crystal(super.game, super.wx, double y, double r, this.fromTop) {
    radius = r;
    position.y = y;
    _buildShape();
  }
  final bool fromTop;
  late List<Offset> spikes;
  double pulse = 0;

  void _buildShape() {
    final r = game.rnd;
    spikes = [];
    final n = 3 + r.nextInt(3);
    for (var i = 0; i < n; i++) {
      final ang = (i / n) * pi * 2 + r.nextDouble() * .6;
      final len = radius * (0.7 + r.nextDouble() * .6);
      spikes.add(Offset(cos(ang) * len, sin(ang) * len));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    pulse += dt;
  }

  @override
  void render(Canvas canvas) {
    final zone = game.zone;
    final breathe = 1 + sin(pulse * 2.4) * .05;
    canvas.save();
    canvas.scale(breathe);
    // mobs.png — kristal topaç yaratık
    final img = Art.mobs;
    if (img != null && Art.mobCells.length > Art.mobCrystal) {
      canvas.rotate(sin(pulse * 1.3) * .12);
      Art.drawCell(canvas, img, Art.mobCells[Art.mobCrystal],
          radius * 2.6, Paint());
      canvas.restore();
      return;
    }
    final path = Path()..moveTo(0, 0);
    for (final p in spikes) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(colors: [
          Color.lerp(zone.wall, const Color(0xFF000000), .2)!,
          const Color(0xFF05030A),
        ]).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * game.s
        ..color = zone.accent.withValues(alpha: .5),
    );
    canvas.restore();
  }
}

/// Düşen Stalaktit — üst duvarda belirir, uyarı verir, düşer
class Stalactite extends GameEntity {
  Stalactite(super.game, super.wx, double topY) : warned = false {
    radius = 13 * game.s;
    position.y = topY - 6 * game.s;
  }
  bool warned;
  double warnT = 0;
  double vy = 0;
  bool falling = false;
  static const warnDur = .85;

  @override
  void update(double dt) {
    super.update(dt);
    if (!falling) {
      // uyarı ancak ekranda görünürken başlasın
      if (px < game.size.x + 40) {
        warnT += dt;
        if (warnT >= warnDur) falling = true;
      }
    } else {
      vy += 1900 * game.s * dt;
      position.y += vy * dt;
      if (position.y > game.size.y + 60) dead = true;
    }
  }

  @override
  void render(Canvas canvas) {
    final h = radius * 3.4;
    final spike = Path()
      ..moveTo(-radius * 1.3, -h * .5)
      ..lineTo(radius * 1.3, -h * .5)
      ..lineTo(0, h * .6)
      ..close();
    final zone = game.zone;
    canvas.drawPath(
      spike,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [zone.wall, const Color(0xFF0A0512)],
        ).createShader(Rect.fromLTWH(-radius, -h * .5, radius * 2, h)),
    );
    canvas.drawPath(
      spike,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3 * game.s
        ..color = zone.accent.withValues(alpha: falling ? .35 : .8),
    );
  }
}

/// Gölge Avcısı — oyuncuyu yavaşça kovalayan tehlike (geç bölgeler)
class Hunter extends GameEntity {
  Hunter(super.game, super.wx, double cy) {
    radius = 15 * game.s;
    position.y = cy;
  }
  double t = 0;
  double wob = 0;

  @override
  void update(double dt) {
    super.update(dt);
    t += dt;
    wob = sin(t * 6) * .5;
    // oyuncuya doğru yumuşak kovalama
    final dy = game.playerPos.dy - position.y;
    position.y += dy.clamp(-70, 70) * game.s * .9 * dt;
    // hafif ileri sürtünme — ekranda kalmasın diye dünya hızında kalsın
  }

  @override
  void render(Canvas canvas) {
    final r = radius;
    final breathe = 1 + sin(t * 5) * .08;
    canvas.save();
    canvas.scale(breathe);
    // mobs.png — yarasa
    final img = Art.mobs;
    if (img != null && Art.mobCells.length > Art.mobBat) {
      canvas.rotate(wob * .25);
      Art.drawCell(
          canvas, img, Art.mobCells[Art.mobBat], r * 3.4, Paint());
      canvas.restore();
      return;
    }
    // pelerinli gölge
    final body = Path()
      ..moveTo(0, -r)
      ..quadraticBezierTo(r * 1.3, -r * .2, r * .8, r * .9)
      ..quadraticBezierTo(r * .2, r * .55, 0, r * .9)
      ..quadraticBezierTo(-r * .2, r * .55, -r * .8, r * .9)
      ..quadraticBezierTo(-r * 1.3, -r * .2, 0, -r)
      ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xFF0B0716));
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * game.s
        ..color = const Color(0xFFFF5A5A).withValues(alpha: .55),
    );
    // tek kızıl göz
    canvas.drawCircle(Offset(r * .15, -r * .2), r * .22,
        Paint()..color = const Color(0xFFFF4040));
    canvas.drawCircle(Offset(r * .15, -r * .2), r * .1,
        Paint()..color = const Color(0xFFFFE0E0));
    canvas.restore();
  }
}

/// Gölge Kapısı — bölge sınırlarını bekleyen mini boss.
/// Tüneli kaplayan iki karanlık blok; aralarındaki geçit dikeyde salınır.
/// Oyuncu aralığı yakalayıp geçmek zorunda.
class BossGate extends GameEntity {
  BossGate(super.game, super.wx) {
    radius = 30 * game.s;
    position.y = 0;
    half = 15 * game.s;
    phase = game.rnd.nextDouble() * pi * 2;
  }
  double phase = 0;   // salınım fazı
  int hp = 3;         // Işık Darbesi ile kırılır
  double flash = 0;   // darbe flaşı
  double t = 0;
  double half = 0;
  bool warned = false;
  bool passed = false;

  /// 0→1→2 — hp düştükçe kapı hızlanır ve geçit daralır
  int get stage => 3 - hp;

  double get gapHalf => (55 - stage * 7) * game.s;

  double get gapY {
    final cy = game.tunnel.cAt(worldX);
    final hw = game.tunnel.hAt(worldX);
    return cy + sin(t * (1.4 + stage * .5) + phase) * hw * .32;
  }

  /// Işık Darbesi hasarı — true dönerse kapı kırıldı
  bool hit() {
    hp--;
    flash = .5;
    if (hp <= 0) {
      dead = true;
      return true;
    }
    return false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    t += dt;
    if (flash > 0) flash -= dt;
    if (!warned && px < game.size.x + 100) {
      warned = true;
      game.floatText('GÖLGE KAPISI', game.size.x * .55, game.size.y * .2,
          const Color(0xFFFF6B5A), big: true, dur: 1.5);
    }
  }

  @override
  void render(Canvas canvas) {
    final s = game.s;
    final top = game.tunnel.topAt(worldX);
    final bot = game.tunnel.bottomAt(worldX);
    final gy = gapY;
    final gh = gapHalf;
    // hasar aldıkça renk kızıllaşır
    const accents = [Color(0xFFFF5A5A), Color(0xFFFF4444), Color(0xFFFF2222)];
    final accent = accents[stage.clamp(0, 2)];
    final pulse = (.55 + .3 * sin(t * (5 + stage * 2))) + flash * 1.5;

    // karanlık bloklar
    final body = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [Color(0xFF160E24), Color(0xFF05030A)],
      ).createShader(Rect.fromLTRB(-half, 0, half, 10));
    canvas.drawRect(Rect.fromLTRB(-half, top - 30 * s, half, gy - gh), body);
    canvas.drawRect(Rect.fromLTRB(-half, gy + gh, half, bot + 30 * s), body);

    // çatlaklar — 2. ve 3. fazda bloklar yarılır
    if (stage >= 1) {
      final crack = Paint()
        ..color = accent.withValues(alpha: .35 + flash)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * s;
      for (var i = 0; i <= stage; i++) {
        final x0 = -half + (i + 1) * (half * 2 / (stage + 2));
        final j = sin(worldX * .13 + i * 7.3) * 8 * s;
        canvas.drawPath(
          Path()
            ..moveTo(x0, gy - gh)
            ..lineTo(x0 + j, gy - gh - 22 * s)
            ..lineTo(x0 - j * .6, gy - gh - 45 * s),
          crack,
        );
        canvas.drawPath(
          Path()
            ..moveTo(x0, gy + gh)
            ..lineTo(x0 - j, gy + gh + 22 * s)
            ..lineTo(x0 + j * .6, gy + gh + 45 * s),
          crack,
        );
      }
    }

    // geçit kenarları — nabız gibi atan kızıl çizgi
    final edge = Paint()
      ..color = accent.withValues(alpha: pulse.clamp(0, 1))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * s
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * s);
    canvas.drawLine(Offset(-half, gy - gh), Offset(half, gy - gh), edge);
    canvas.drawLine(Offset(-half, gy + gh), Offset(half, gy + gh), edge);

    // dişler — bloklardan geçide doğru sivrilen
    final tooth = Paint()..color = const Color(0xFF0B0716);
    for (double x = -half; x <= half - 8 * s; x += 11 * s) {
      canvas.drawPath(
        Path()
          ..moveTo(x, gy - gh)
          ..lineTo(x + 5.5 * s, gy - gh + 9 * s)
          ..lineTo(x + 11 * s, gy - gh)
          ..close(),
        tooth,
      );
      canvas.drawPath(
        Path()
          ..moveTo(x, gy + gh)
          ..lineTo(x + 5.5 * s, gy + gh - 9 * s)
          ..lineTo(x + 11 * s, gy + gh)
          ..close(),
        tooth,
      );
    }

    // üst blokta kızıl göz — faz ilerledikçe büyür ve kızarır
    if (gy - gh - top > 34 * s) {
      final eyeY = (top + gy - gh) / 2;
      final er = (4 + stage * 1.4 + flash * 3) * s;
      canvas.drawCircle(Offset(0, eyeY), er * 2,
          Paint()
            ..color = accent.withValues(alpha: .22 + flash * .3)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * s));
      canvas.drawCircle(Offset(0, eyeY), er, Paint()..color = accent);
      canvas.drawCircle(Offset(0, eyeY), er * .4,
          Paint()..color = const Color(0xFFFFE0E0));
    }
  }
}

/// Gölge Güvesi — tünelde sinüs dalgasıyla uçan tehlike
class Moth extends GameEntity {
  Moth(GlowdeepGame game, double wx, double cy, this.amp, this.freq, this.phase)
      : super(game, wx) {
    baseY = cy;
    radius = 17 * game.s;
  }
  double baseY = 0;
  final double amp, freq, phase;
  double t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    t += dt;
    position.y = baseY + sin(t * freq + phase) * amp;
  }

  @override
  void render(Canvas canvas) {
    // mobs.png — güve
    final img = Art.mobs;
    if (img != null && Art.mobCells.length > Art.mobMoth) {
      final flap = 1 + sin(t * 10) * .07;
      canvas.save();
      canvas.scale(flap, 2 - flap);
      Art.drawCell(
          canvas, img, Art.mobCells[Art.mobMoth], radius * 3.2, Paint());
      canvas.restore();
      return;
    }
    final flap = sin(t * 14) * .6;
    final body = Paint()..color = const Color(0xFF0A0614);
    final wing = Paint()..color = game.zone.accent.withValues(alpha: .28);
    final r = radius;
    for (final dir in [-1, 1]) {
      canvas.save();
      canvas.rotate(dir * (0.5 + flap * .4));
      canvas.drawOval(Rect.fromCenter(center: Offset(0, dir * r * .7), width: r * 1.4, height: r * .9), wing);
      canvas.restore();
    }
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * .9, height: r * 1.5), body);
  }
}

/// Karanlık Denizanası — derin bölgelerde yavaşça süzülen tehlike.
/// Güveden yavaş ama daha büyük ve sürekli aşağı kayar.
class Jelly extends GameEntity {
  Jelly(super.game, super.wx, double cy) {
    radius = 19 * game.s;
    baseY = cy;
    phase = game.rnd.nextDouble() * pi * 2;
  }
  double baseY = 0;
  double phase = 0;
  double t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    t += dt;
    position.y = baseY + sin(t * 1.1 + phase) * 42 * game.s + t * 6 * game.s;
  }

  @override
  void render(Canvas canvas) {
    final img = Art.mobs;
    if (img != null && Art.mobCells.length > Art.mobJelly) {
      // nabız — gövde alttan basıklaşıp geri açılır
      final sq = 1 + sin(t * 4 + phase) * .09;
      canvas.save();
      canvas.scale(2 - sq, sq);
      Art.drawCell(
          canvas, img, Art.mobCells[Art.mobJelly], radius * 3.6, Paint());
      canvas.restore();
      return;
    }
    final r = radius;
    final body = Paint()..color = const Color(0xCC3D1650);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(0, -r * .2), width: r * 2, height: r * 1.5), body);
    final tent = Paint()
      ..color = const Color(0xFFB78BFF).withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * game.s;
    for (var i = -2; i <= 2; i++) {
      canvas.drawPath(
        Path()
          ..moveTo(i * r * .3, r * .4)
          ..quadraticBezierTo(
              i * r * .35 + sin(t * 3 + i) * 4, r * .8, i * r * .3, r * 1.15),
        tent,
      );
    }
  }
}
