import 'dart:math';
import 'dart:ui';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../art.dart';
import '../audio.dart';
import '../data.dart';
import '../save.dart';
import 'background.dart';
import 'darkness.dart';
import 'entities.dart';
import 'fx.dart';
import 'player.dart';
import 'tunnel.dart';

enum Phase { menu, playing, dead }

class HudData {
  final int depth, lum, combo, shield;
  final String zone;
  final double progress; // sonraki bölgeye ilerleme (0..1), son bölgede -1
  final double pulse;    // Işık Darbesi hazırlığı 0..1, yoksa -1
  const HudData(this.depth, this.lum, this.combo, this.shield, this.zone,
      [this.progress = -1, this.pulse = -1]);
}

class RunStats {
  final int depth, lum, nearMisses;
  final bool record;
  final String cause;
  const RunStats(this.depth, this.lum, this.nearMisses, this.record, this.cause);
}

class GlowdeepGame extends FlameGame {
  static const meterPx = 48.0;

  final rnd = Random();
  final save = SaveData.I;

  Phase phase = Phase.menu;
  bool pausedFlag = false;
  double s = 1;                 // ekran ölçeği
  double time = 0;
  double scrollX = 0;
  double speed = 0;
  bool thrustHeld = false;

  late CaveTunnel tunnel;
  late Lumora player;
  final List<GameEntity> entities = [];

  // koşu durumu
  int runLum = 0;
  int combo = 0;
  int runBestCombo = 0;
  double comboT = 0;
  int shield = 0;
  double invulnT = 0;
  double lightBoostT = 0;
  bool revived = false;
  bool mercyUsed = false;
  int runNearMiss = 0;
  double deathT = 0;
  double pulseCd = 0;    // Işık Darbesi bekleme süresi
  double _lastTapT = -10; // çift dokunuş algısı
  double nextSpawnX = 0;
  int _lastZoneIdx = 0;
  final Set<int> _gatesSpawned = {}; // bu koşuda spawn edilen bölge kapıları

  Zone zone = zones[0];
  final shake = Shake();
  final hud = ValueNotifier<HudData>(const HudData(0, 0, 0, 0, ''));

  // UI köprüsü
  void Function(RunStats)? onDeath;
  void Function(Chapter)? onChapter;

  double get depth => scrollX / meterPx;
  double get playerScreenX => size.x * .34;
  Offset get playerPos => Offset(playerScreenX, player.position.y);
  double get lightR => lightRadiusFor(save.upg('light')) * s;
  double get magnetR => magnetFor(save.upg('magnet')) * s;

  @override
  Future<void> onLoad() async {
    s = size.y / 780;
    // sprite'lar main()'de yüklenmiş olmalı — değilse burada telafi et
    if (Art.coin == null || Art.mobs == null) await Art.load();
    add(CaveBackground(this)..priority = -10);
    tunnel = CaveTunnel(this)..priority = -5;
    add(tunnel);
    tunnel.reset();
    player = Lumora(this)..priority = 5;
    player.position = Vector2(playerScreenX, size.y * .5);
    add(player);
    add(DarknessVeil(this)..priority = 10);
    add(ForegroundRocks(this)..priority = 11);
    add(GlowPass(this)..priority = 12);
    nextSpawnX = size.x + 400;
  }

  @override
  void onGameResize(Vector2 size) {
    s = size.y / 780;
    super.onGameResize(size);
  }

  // ------------------------------------------------------------ GİRİŞ
  void press() {
    thrustHeld = true;
    // çift dokunuş → Işık Darbesi
    if (phase == Phase.playing && time - _lastTapT < .3) tryPulse();
    _lastTapT = time;
  }
  void release() => thrustHeld = false;

  /// Işık Darbesi — yakın gölgeleri dağıtır, Gölge Kapısı'na hasar verir
  void tryPulse() {
    final lvl = save.upg('pulse');
    if (lvl == 0 || phase != Phase.playing || pulseCd > 0) return;
    pulseCd = pulseCooldownFor(lvl);
    final r = pulseRadiusFor(lvl) * s;
    final pc = Offset(playerScreenX, player.position.y);
    add(PulseWave(center: Vector2(pc.dx, pc.dy), maxR: r, color: player.skin.glow)
      ..priority = 9);
    shake.add(3 * s);
    Sfx.I.play('pulse');
    save.buzz(HapticFeedback.mediumImpact);
    var hits = 0;
    for (final e in entities) {
      if (e.dead || e is Orb) continue;
      final d = (Offset(e.px, e.position.y) - pc).distance;
      if (d > r) continue;
      if (e is BossGate) {
        if (e.hit()) {
          runLum += 20;
          Sfx.I.play('break');
          shake.add(10 * s);
          floatText('KAPI KIRILDI  +20', e.px, e.gapY,
              const Color(0xFFFF9D6B), big: true, dur: 1.6);
          for (var i = 0; i < 20; i++) {
            final a = rnd.nextDouble() * pi * 2;
            final sp = (60 + rnd.nextDouble() * 200) * s;
            add(Particle(
              pos: Vector2(e.px, e.gapY),
              vel: Vector2(cos(a) * sp, sin(a) * sp),
              life: .4 + rnd.nextDouble() * .5,
              color: const Color(0xFFFF6B5A),
              size: 3 * s,
              drag: .94,
            )..priority = 15);
          }
        } else {
          floatText('ÇATLADI!', e.px, e.gapY, const Color(0xFFFF8A5A), dur: .9);
        }
        hits++;
      } else {
        e.dead = true;
        hits++;
        for (var i = 0; i < 5; i++) {
          final a = rnd.nextDouble() * pi * 2;
          final sp = (50 + rnd.nextDouble() * 140) * s;
          add(Particle(
            pos: Vector2(e.px, e.position.y),
            vel: Vector2(cos(a) * sp, sin(a) * sp),
            life: .3 + rnd.nextDouble() * .3,
            color: player.skin.glow,
            size: 2.4 * s,
            drag: .94,
          )..priority = 15);
        }
      }
    }
    if (hits > 0) {
      floatText(hits == 1 ? 'GÖLGE DAĞILDI' : '$hits GÖLGE DAĞILDI',
          pc.dx + 30, pc.dy - 46, const Color(0xFF7FF5FF));
    }
  }

  // ------------------------------------------------------------ AKIŞ
  void startRun() {
    phase = Phase.playing;
    scrollX = 0;
    time = 0;
    runLum = 0;
    combo = 0;
    runBestCombo = 0;
    comboT = 0;
    runNearMiss = 0;
    revived = false;
    invulnT = 1.5;
    mercyUsed = false;
    pulseCd = 0;
    shield = shieldFor(save.upg('shield'));
    player.vy = 0;
    player.position.y = size.y * .5;
    lightBoostT = 0;
    _lastZoneIdx = 0;
    _gatesSpawned.clear();
    tunnel.reset();
    for (final e in entities) {
      e.removeFromParent();
    }
    entities.clear();
    nextSpawnX = size.x + 700;
    Sfx.I.stopMelody();
    Sfx.I.startAmbient();
    // ilk oyunda öğretici
    if (!save.tutorialDone) {
      save.tutorialDone = true;
      save.save();
      floatText('BASILI TUT — YÜKSEL', size.x * .5, size.y * .38, const Color(0xFFFFD66B), big: true, dur: 2.6);
      floatText('bırakınca süzülürsün', size.x * .5, size.y * .46, const Color(0xFF7FF5FF), dur: 2.6);
    }
  }

  void revive() {
    if (revived || save.lum < 50) return;
    save.lum -= 50;
    save.revives++;
    save.save();
    revived = true;
    phase = Phase.playing;
    invulnT = 2.5;
    player.vy = 0;
    // yakın tehlikeleri temizle
    for (final e in entities) {
      if (e is! Orb && (e.px - playerScreenX).abs() < 500) e.dead = true;
    }
    Sfx.I.play('chapter');
    save.buzz(HapticFeedback.mediumImpact);
  }

  void backToMenu() {
    phase = Phase.menu;
    scrollX = 0;
    for (final e in entities) {
      e.removeFromParent();
    }
    entities.clear();
    Sfx.I.stopAmbient();
    Sfx.I.startMelody();
    tunnel.reset();
    player.position.y = size.y * .5;
    player.vy = 0;
  }

  void _die(String cause) {
    phase = Phase.dead;
    deathT = 0;
    shake.add(14 * s);
    Sfx.I.play('hit');
    save.buzz(HapticFeedback.heavyImpact);
    // patlama parçacıkları
    for (var i = 0; i < 34; i++) {
      final a = rnd.nextDouble() * pi * 2;
      final sp = (80 + rnd.nextDouble() * 260) * s;
      add(Particle(
        pos: Vector2(playerScreenX, player.position.y),
        vel: Vector2(cos(a) * sp, sin(a) * sp),
        life: .5 + rnd.nextDouble() * .7,
        color: i.isEven ? player.skin.glow : const Color(0xFFFFF3D0),
        size: 3.4 * s,
        drag: .95,
      )..priority = 15);
    }
    // istatistik
    save.runs++;
    save.ensureToday();
    save.dayRuns++;
    save.dayLum += runLum;
    final d = depth.round();
    if (d > save.dayDepthBest) save.dayDepthBest = d;
    save.dayNear += runNearMiss;
    save.dayTotal += d;
    if (runLum > save.dayBestRunLum) save.dayBestRunLum = runLum;
    if (runBestCombo > save.dayBestCombo) save.dayBestCombo = runBestCombo;
    save.totalDepth += d;
    save.totalLum += runLum;
    save.nearMisses += runNearMiss;
    if (runLum > save.bestRunLum) save.bestRunLum = runLum;
    final zi = ZoneBlend.indexAt(depth) + 1;
    if (zi > save.maxZone) save.maxZone = zi;
    final record = d > save.bestDepth;
    if (record) save.bestDepth = d;
    save.lum += runLum;
    save.save();
    Future.delayed(const Duration(milliseconds: 900), () {
      onDeath?.call(RunStats(d, runLum, runNearMiss, record, cause));
    });
  }

  // ------------------------------------------------------------ SPAWN
  void _spawnStep() {
    final limit = scrollX + size.x + 500;
    while (nextSpawnX < limit) {
      final wx = nextSpawnX;
      final zi = ZoneBlend.indexAt(wx / meterPx);

      // bölge sınırı yaklaşıyorsa Gölge Kapısı (mini boss) koy
      var gated = false;
      for (var i = 1; i < zones.length; i++) {
        final bx = zones[i].atMeters * meterPx;
        if (_gatesSpawned.contains(i) || bx < wx || bx >= wx + 260) continue;
        _gatesSpawned.add(i);
        _add(BossGate(this, bx));
        // kapının içine/arkasına düşen coinler ulaşılamaz olur — temizle
        for (final e in entities) {
          if (e is Orb && (e.worldX - bx).abs() < 140) e.dead = true;
        }
        nextSpawnX = bx + 420 * s; // kapı sonrası nefes payı
        gated = true;
        break;
      }
      if (gated) continue;

      final roll = rnd.nextDouble();
      final hazardW = .13 + zi * .035; // derinlikle tehlike yoğunluğu artar

      if (roll < .38) {
        _spawnOrbArc(wx);
        nextSpawnX += 200 + rnd.nextDouble() * 170;
      } else if (roll < .41 && zi >= 1) {
        _spawnMegaOrb(wx);
        nextSpawnX += 300;
      } else if (roll < .41 + hazardW) {
        _spawnCrystal(wx);
        nextSpawnX += 190 + rnd.nextDouble() * 120;
      } else if (zi >= 2 && roll < .41 + hazardW + .06 + zi * .01) {
        _spawnStalactite(wx);
        nextSpawnX += 200 + rnd.nextDouble() * 120;
      } else if (zi >= 2 && roll < .41 + hazardW + .06 + zi * .01 + .05) {
        _spawnHunter(wx);
        nextSpawnX += 320 + rnd.nextDouble() * 160;
      } else if (roll < .52 + hazardW + .14 + zi * .015) {
        _spawnMoth(wx);
        nextSpawnX += 210 + rnd.nextDouble() * 140;
      } else {
        nextSpawnX += 120 + rnd.nextDouble() * 160;
      }
    }
  }

  void _spawnOrbArc(double wx) {
    final n = 4 + rnd.nextInt(3);
    // ark merkezini aralığın ortasındaki tünel hattından al
    final midX = wx + (n - 1) * 17 * s;
    final cy = tunnel.cAt(midX);
    final hw = tunnel.hAt(midX);
    final arcY = cy + (rnd.nextDouble() * 2 - 1) * hw * .35;
    final lift = (rnd.nextBool() ? 1 : -1) * (18 + rnd.nextDouble() * 16) * s;
    for (var i = 0; i < n; i++) {
      final t = n == 1 ? .5 : i / (n - 1);
      final ox = wx + i * 34 * s;
      var y = arcY + sin(t * pi) * lift;
      // her coin kendi x'indeki tünel duvarlarının içinde kalsın —
      // tünel kavisli olduğundan tek noktadan hesap duvara taşıyordu
      y = y.clamp(tunnel.topAt(ox) + 20 * s, tunnel.bottomAt(ox) - 20 * s);
      _add(Orb(this, ox, y));
    }
  }

  void _spawnCrystal(double wx) {
    final top = rnd.nextBool();
    final hw = tunnel.hAt(wx);
    final cy = tunnel.cAt(wx);
    final r = (26 + rnd.nextDouble() * 20) * s;
    final protrude = r * (1.1 + rnd.nextDouble() * .7);
    final y = top ? cy - hw + protrude * .4 : cy + hw - protrude * .4;
    _add(Crystal(this, wx, y, protrude * .8, top));
    // bazen karşı duvardan da küçük kristal → kapı hissi
    if (rnd.nextDouble() < .3 + ZoneBlend.indexAt(wx / meterPx) * .05) {
      final r2 = r * .7;
      final y2 = top ? cy + hw - r2 * .35 : cy - hw + r2 * .35;
      _add(Crystal(this, wx + 30 * s, y2, r2, !top));
    }
  }

  void _spawnMoth(double wx) {
    final cy = tunnel.cAt(wx);
    final hw = tunnel.hAt(wx);
    // derinlerde güve yerine denizanası
    if (ZoneBlend.indexAt(wx / meterPx) >= 3 && rnd.nextDouble() < .3) {
      _add(Jelly(this, wx, cy + (rnd.nextDouble() * 2 - 1) * hw * .4));
      return;
    }
    final amp = hw * (.3 + rnd.nextDouble() * .35);
    final freq = 2.2 + rnd.nextDouble() * 1.6;
    _add(Moth(this, wx, cy, amp, freq, rnd.nextDouble() * pi * 2));
  }

  void _spawnMegaOrb(double wx) {
    _add(MegaOrb(this, wx, tunnel.cAt(wx)));
  }

  void _spawnStalactite(double wx) {
    _add(Stalactite(this, wx, tunnel.topAt(wx)));
  }

  void _spawnHunter(double wx) {
    _add(Hunter(this, wx, tunnel.cAt(wx) + (rnd.nextDouble() * 2 - 1) * 80 * s));
  }

  void _add(GameEntity e) {
    entities.add(e);
    add(e);
  }

  // ------------------------------------------------------------ FX
  void spawnTrail(double x, double y, Color c) {
    add(Particle(
      pos: Vector2(x - 10 * s, y + (rnd.nextDouble() * 6 - 3) * s),
      vel: Vector2(-(50 + rnd.nextDouble() * 40) * s, (rnd.nextDouble() * 20 - 10) * s),
      life: .45 + rnd.nextDouble() * .3,
      color: c,
      size: 2.6 * s,
      drag: .94,
    )..priority = 15);
  }

  void spawnPickupFx(double x, double y) {
    for (var i = 0; i < 7; i++) {
      final a = rnd.nextDouble() * pi * 2;
      add(Particle(
        pos: Vector2(x, y),
        vel: Vector2(cos(a) * 90 * s, sin(a) * 90 * s),
        life: .35,
        color: const Color(0xFFFFE9A8),
        size: 2.2 * s,
      )..priority = 15);
    }
  }

  void floatText(String text, double x, double y, Color color, {bool big = false, double dur = 1.1}) {
    add(FloatText(Vector2(x, y), text, color, big: big, dur: dur)..priority = 16);
  }

  // ------------------------------------------------------------ UPDATE
  @override
  void update(double dt) {
    if (pausedFlag) return;
    super.update(dt);
    time += dt;
    zone = ZoneBlend.at(depth);
    shake.offset(dt);

    switch (phase) {
      case Phase.menu:
        scrollX += 60 * s * dt;
        _spawnStep();
        // oyuncu ortada nazikçe süzülür
        final target = tunnel.cAt(scrollX + playerScreenX);
        player.position.y += (target - player.position.y) * 2.2 * dt;
        player.position.x = playerScreenX;
        break;

      case Phase.playing:
        _updatePlaying(dt);
        break;

      case Phase.dead:
        deathT += dt;
        scrollX += speed * dt * max(0, 1 - deathT * 3); // yavaşla
        break;
    }

    // ölü varlıkları temizle
    for (var i = entities.length - 1; i >= 0; i--) {
      if (entities[i].dead) {
        entities[i].removeFromParent();
        entities.removeAt(i);
      }
    }
  }

  void _updatePlaying(double dt) {
    final wings = wingsFor(save.upg('wings'));
    speed = (140 + depth * 1.05).clamp(140.0, 310.0).toDouble() * s;
    scrollX += speed * dt;
    _spawnStep();
    if (invulnT > 0) invulnT -= dt;
    if (pulseCd > 0) pulseCd -= dt;

    // --- fizik
    if (lightBoostT > 0) lightBoostT -= dt;
    final grav = 1250 * s * wings;
    final thrust = -2080 * s * wings;
    player.vy += (thrustHeld ? thrust : grav) * dt;
    player.vy = player.vy.clamp(-430 * s, 520 * s).toDouble();
    player.position.y += player.vy * dt;
    player.position.x = playerScreenX;

    final pwX = scrollX + playerScreenX;
    final pr = 12 * s;

    // --- duvar çarpışması
    final topLim = tunnel.topAt(pwX) + pr;
    final botLim = tunnel.bottomAt(pwX) - pr;
    if (invulnT > 0) {
      // ölümsüzlükte koridor içinde tut — duvara yapışıp sürüklenme olmasın
      if (topLim < botLim) {
        if (player.position.y < topLim) {
          player.position.y = topLim;
          player.vy = max(0.0, player.vy);
        } else if (player.position.y > botLim) {
          player.position.y = botLim;
          player.vy = min(0.0, player.vy);
        }
      } else {
        // koridor kapanacak kadar daraldıysa merkezde tut
        player.position.y = tunnel.cAt(pwX);
        player.vy = 0;
      }
    } else if (player.position.y - pr < tunnel.topAt(pwX) ||
        player.position.y + pr > tunnel.bottomAt(pwX)) {
      _hitWall();
      return;
    }

    // --- varlık etkileşimi
    final pPos = playerPos;
    for (final e in entities) {
      if (e.dead) continue;
      final dx = e.px - pPos.dx;
      final dy = e.position.y - pPos.dy;
      final dist = sqrt(dx * dx + dy * dy);

      if (e is Orb) {
        if (!e.magnetOn && dist < magnetR * (e is MegaOrb ? 1.3 : 1)) e.magnetOn = true;
        if (dist < e.radius + pr) {
          e.dead = true;
          _pickupOrb(e);
        }
      } else if (e is BossGate) {
        // kapı: yatayda çakışırken geçit aralığının dışındaysan çarpma
        final inX = (e.px - pPos.dx).abs() < e.half + pr;
        if (inX) {
          final margin = e.gapHalf - (pPos.dy - e.gapY).abs();
          e.minDist = min(e.minDist, margin);
          if (margin < 0 && !_takeHit(e)) return;
        }
        if (!e.passed && e.px < pPos.dx - e.half) {
          e.passed = true;
          runLum += 5;
          floatText('KAPI AŞILDI  +5', playerScreenX, player.position.y - 40,
              const Color(0xFFFF9D6B));
          Sfx.I.play('nearmiss');
          // kenarı sıyırarak geçtiysen ekstra ödül
          if (!e.nearChecked && e.minDist >= 0 && e.minDist < 26 * s && invulnT <= 0) {
            e.nearChecked = true;
            _nearMiss(e);
          }
        }
      } else {
        if (dist < minDist0(e)) e.minDist = min(e.minDist, dist);
        if (dist < e.radius * .82 + pr) {
          if (!_takeHit(e)) return;
        } else if (!e.nearChecked && e.px < pPos.dx - e.radius - 20) {
          e.nearChecked = true;
          if (e.minDist < e.radius + 52 * s && invulnT <= 0) _nearMiss(e);
        }
      }
    }

    // --- kombo sayacı
    if (comboT > 0) {
      comboT -= dt;
      if (comboT <= 0) combo = 0;
    }

    // --- bölge anonsu
    final zi = ZoneBlend.indexAt(depth);
    if (zi != _lastZoneIdx) {
      _lastZoneIdx = zi;
      runLum += 8;
      floatText(zones[zi].name.toUpperCase(), size.x * .5, size.y * .3, zone.accent, big: true, dur: 1.8);
      floatText('+8 ◈ bölge bonusu', size.x * .5, size.y * .36, const Color(0xFFFFD66B), dur: 1.8);
      Sfx.I.play('nearmiss');
    }

    // --- bölüm geçişi
    for (final ch in chapters) {
      if (ch.atMeters > 0 && depth >= ch.atMeters && !save.chaptersSeen.contains(ch.atMeters)) {
        save.chaptersSeen.add(ch.atMeters);
        save.save();
        pausedFlag = true;
        Sfx.I.play('chapter');
        onChapter?.call(ch);
        break;
      }
    }

    double prog = -1;
    if (zi < zones.length - 1) {
      final cur = zones[zi].atMeters.toDouble();
      prog = ((depth - cur) / (zones[zi + 1].atMeters - cur)).clamp(0.0, 1.0);
    }
    final pl = save.upg('pulse');
    hud.value = HudData(
        depth.round(), runLum, combo, shield, zone.name, prog,
        pl == 0 ? -1 : (1 - pulseCd / pulseCooldownFor(pl)).clamp(0.0, 1.0));
  }

  double minDist0(GameEntity e) => e.radius + 200 * s;

  void _pickupOrb(Orb e) {
    combo++;
    if (combo > runBestCombo) runBestCombo = combo;
    comboT = 1.6;
    if (e is MegaOrb) {
      runLum += 12;
      lightBoostT = 1.6;
      shake.add(4 * s);
      floatText('AURORA +12', e.px, e.position.y - 26, const Color(0xFF9FE8FF), big: true);
      Sfx.I.play('chapter');
      save.buzz(HapticFeedback.mediumImpact);
      spawnPickupFx(e.px, e.position.y);
      return;
    }
    var v = 1 + min(combo ~/ 4, 4).toInt();
    if (rnd.nextDouble() < luckFor(save.upg('luck'))) v *= 2;
    runLum += v;
    spawnPickupFx(e.px, e.position.y);
    if (v > 1) {
      floatText('+$v', e.px, e.position.y - 20, const Color(0xFFFFD66B));
    }
    Sfx.I.pickup(combo);
    save.buzz(HapticFeedback.lightImpact);
  }

  void _nearMiss(GameEntity e) {
    runNearMiss++;
    runLum += 2;
    floatText('SIYIRDI  +2', playerScreenX, player.position.y - 34, const Color(0xFF7FF5FF));
    Sfx.I.play('nearmiss');
  }

  bool _takeHit(GameEntity e) {
    if (invulnT > 0) return true;
    if (shield > 0) {
      shield--;
      invulnT = 1.6;
      e.dead = true;
      shake.add(8 * s);
      Sfx.I.play('shield');
      save.buzz(HapticFeedback.mediumImpact);
      floatText('KALKAN!', playerScreenX, player.position.y - 34, const Color(0xFF37E0C8));
      return true;
    }
    _die(e is Moth
        ? 'Gölge güvesi ışığını yuttu'
        : e is Hunter
            ? 'Gölge avcısı kıvılcımı söndürdü'
            : e is Stalactite
                ? 'Düşen karanlık seni yakaladı'
                : e is BossGate
                    ? 'Gölge Kapısı seni kıstırdı'
                    : 'Gölge kristali ışığını kırdı');
    return false;
  }

  void _hitWall() {
    // merhamet sıyırması — koşu başına bir kez duvar affedilir
    if (!mercyUsed) {
      mercyUsed = true;
      invulnT = 1.4;
      player.position.y = tunnel.cAt(scrollX + playerScreenX);
      player.vy = 0;
      shake.add(6 * s);
      Sfx.I.play('shield');
      save.buzz(HapticFeedback.mediumImpact);
      floatText('SON ŞANS!', playerScreenX, player.position.y - 40, const Color(0xFFFF9D6B), big: true);
      return;
    }
    if (shield > 0) {
      shield--;
      invulnT = 1.6;
      player.position.y = tunnel.cAt(scrollX + playerScreenX);
      player.vy = 0;
      shake.add(8 * s);
      Sfx.I.play('shield');
      floatText('KALKAN!', playerScreenX, player.position.y - 34, const Color(0xFF37E0C8));
      return;
    }
    _die('Karanlık duvarlar seni yuttu');
  }

  @override
  void renderTree(Canvas canvas) {
    canvas.save();
    final o = shake.offset(0);
    if (o != Offset.zero) canvas.translate(o.dx, o.dy);
    super.renderTree(canvas);
    canvas.restore();
  }
}
