import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'art.dart';
import 'audio.dart';
import 'data.dart';
import 'game/glowdeep_game.dart';
import 'icons.dart';
import 'save.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SaveData.I.load();
  await GameIcons.load();
  await Art.load();
  await Sfx.I.init();
  Sfx.I.muted = SaveData.I.muted;
  Sfx.I.startMelody();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const GlowdeepApp());
}

// ============================================================================
// TASARIM SİSTEMİ
// ============================================================================
const kGold = Color(0xFFFFC845);
const kGoldSoft = Color(0xFFFFD66B);
const kTeal = Color(0xFF37E0C8);
const kDanger = Color(0xFFFF6B5A);
const kViolet = Color(0xFFB78BFF);
const kEmber = Color(0xFFFF9D6B);
const kRose = Color(0xFFFF9DB4);
const kIce = Color(0xFF7FF5FF);
const kInk = Color(0xFF04060D);
const kPanel = Color(0xF50C1224);
const kCard = Color(0x0FFFFFFF);
const kLine = Color(0x1AFFFFFF);

/// Epik başlık fontu — sadece logo ve bölüm adı için (variable Cinzel)
TextStyle cinzel(double size,
        {Color color = Colors.white, double spacing = 2, int wght = 800}) =>
    TextStyle(
      fontFamily: 'Cinzel',
      fontSize: size,
      color: color,
      letterSpacing: spacing,
      fontVariations: [FontVariation('wght', wght.toDouble())],
    );

/// UI başlıkları — yumuşak geometrik Poppins
TextStyle heading(double size,
        {Color color = Colors.white, double spacing = 1.5, FontWeight w = FontWeight.w800}) =>
    TextStyle(
      fontFamily: 'Poppins',
      fontSize: size,
      color: color,
      letterSpacing: spacing,
      fontWeight: w,
      height: 1.1,
    );

/// Küçük bölüm/etiket metni
TextStyle caps(double size, Color color, {double spacing = 2.4}) => TextStyle(
      fontSize: size,
      color: color,
      letterSpacing: spacing,
      fontWeight: FontWeight.w700,
    );

class GlowdeepApp extends StatelessWidget {
  const GlowdeepApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GLOWDEEP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: kInk,
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Poppins'),
      ),
      home: const HomePage(),
    );
  }
}

enum Screen { none, menu, death, pause, shop, missions, journal, skins, settings }

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomeState();
}

class _HomeState extends State<HomePage> with WidgetsBindingObserver {
  late final GlowdeepGame game;
  Screen screen = Screen.menu;
  RunStats? lastRun;
  Chapter? chapterCard;
  String toast = '';
  int toastIcon = GI.lum;
  int _rankAtRunStart = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game = GlowdeepGame();
    game.onDeath = (stats) => setState(() {
          lastRun = stats;
          screen = Screen.death;
        });
    game.onChapter = (ch) => setState(() => chapterCard = ch);
    if (!SaveData.I.chaptersSeen.contains(0)) {
      chapterCard = chapters.first;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final daily = SaveData.I.claimDaily();
      if (daily > 0) {
        final st = SaveData.I.streakDays;
        _toast(st % 7 == 0
            ? 'Haftalık seri ödülü! +$daily ◈\nSeri: $st gün'
            : 'Günlük ödül: +$daily ◈\nSeri: $st gün');
      } else {
        final idle = SaveData.I.claimIdle();
        if (idle > 0) _toast('Derin Yankı +$idle ◈ getirdi');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      SaveData.I.save();
      if (game.phase == Phase.playing) _pause();
    }
  }

  void _toast(String msg, {int icon = GI.lum}) {
    setState(() {
      toast = msg;
      toastIcon = icon;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && toast == msg) setState(() => toast = '');
    });
  }

  void _play() {
    Sfx.I.play('ui');
    _rankAtRunStart = rankIndexFor(SaveData.I.totalDepth);
    game.startRun();
    setState(() => screen = Screen.none);
  }

  void _pause() {
    game.pausedFlag = true;
    setState(() => screen = Screen.pause);
  }

  void _resume() {
    Sfx.I.play('ui');
    game.pausedFlag = false;
    setState(() => screen = Screen.none);
  }

  void _toMenu() {
    Sfx.I.play('ui');
    game.backToMenu();
    setState(() => screen = Screen.menu);
    final ri = rankIndexFor(SaveData.I.totalDepth);
    if (ri > _rankAtRunStart) {
      _rankAtRunStart = ri;
      _toast('RÜTBE ATLADIN!\nYeni rütben: ${ranks[ri].name}',
          icon: GameIcons.rankBadge(SaveData.I.totalDepth));
      SaveData.I.buzz(HapticFeedback.mediumImpact);
    }
  }

  void _revive() {
    if (SaveData.I.lum < 50) {
      _toast('Yeterli Lum yok');
      return;
    }
    game.revive();
    setState(() => screen = Screen.none);
  }

  Widget _screen() {
    return switch (screen) {
      Screen.menu => MenuScreen(
          onPlay: _play,
          onShop: () => setState(() => screen = Screen.shop),
          onMissions: () => setState(() => screen = Screen.missions),
          onJournal: () => setState(() => screen = Screen.journal),
          onSkins: () => setState(() => screen = Screen.skins),
          onSettings: () => setState(() => screen = Screen.settings),
        ),
      Screen.death => DeathScreen(
          stats: lastRun!,
          canRevive: !game.revived && SaveData.I.lum >= 50,
          onRevive: _revive,
          onRetry: _play,
          onMenu: _toMenu,
        ),
      Screen.pause => PauseScreen(onResume: _resume, onQuit: _toMenu),
      Screen.shop => ShopScreen(
          onBack: () => setState(() => screen = Screen.menu), onToast: _toast),
      Screen.missions => MissionsScreen(
          onBack: () => setState(() => screen = Screen.menu), onToast: _toast),
      Screen.journal => JournalScreen(onBack: () => setState(() => screen = Screen.menu)),
      Screen.skins => SkinsScreen(
          onBack: () => setState(() => screen = Screen.menu), onToast: _toast),
      Screen.settings => SettingsScreen(onBack: () => setState(() => screen = Screen.menu)),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => game.press(),
            onPointerUp: (_) => game.release(),
            onPointerCancel: (_) => game.release(),
            child: GameWidget(game: game),
          ),
          if (screen == Screen.none || screen == Screen.pause)
            _Hud(game: game, onPause: _pause),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween(begin: .965, end: 1.0).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(screen), child: _screen()),
          ),
          if (chapterCard != null)
            ChapterCard(
              chapter: chapterCard!,
              onDone: () => setState(() {
                SaveData.I.chaptersSeen.add(chapterCard!.atMeters);
                SaveData.I.save();
                chapterCard = null;
                game.pausedFlag = false;
              }),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 0, right: 0,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, -.35), end: Offset.zero)
                        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
                    child: child,
                  ),
                ),
                child: toast.isEmpty
                    ? const SizedBox.shrink()
                    : KeyedSubtree(
                        key: ValueKey(toast),
                        child: _Toast(msg: toast, icon: toastIcon)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HUD
// ============================================================================
class _Hud extends StatelessWidget {
  const _Hud({required this.game, required this.onPause});
  final GlowdeepGame game;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ValueListenableBuilder<HudData>(
          valueListenable: game.hud,
          builder: (_, h, _) {
            final accent = game.zone.accent;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  _Pill(icon: GI.depth, text: '${h.depth} m'),
                  const SizedBox(width: 8),
                  _Pill(icon: GI.lum, text: '${h.lum}', gold: true),
                  const SizedBox(width: 8),
                  if (h.shield > 0) _Pill(icon: GI.shield, text: '${h.shield}', teal: true),
                  if (h.pulse >= 0) ...[
                    const SizedBox(width: 8),
                    _PulseHud(ready: h.pulse),
                  ],
                  const Spacer(),
                  if (h.combo >= 4)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ComboBadge(mult: (1 + h.combo ~/ 4).clamp(1, 5)),
                    ),
                  _Pressable(
                    onTap: onPause,
                    child: const _Pill(icon: GI.pause, text: ''),
                  ),
                ]),
                if (h.zone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                        boxShadow: [BoxShadow(color: accent, blurRadius: 6)],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(h.zone.toUpperCase(), style: caps(10, accent)),
                    const Spacer(),
                    if (h.progress >= 0)
                      Text('${(h.progress * 100).round()}%',
                          style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w700)),
                  ]),
                  if (h.progress >= 0) ...[
                    const SizedBox(height: 5),
                    _GlowBar(value: h.progress, color: accent, height: 3),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Kombo çarpanı — değer değişince pop animasyonu
class _ComboBadge extends StatelessWidget {
  const _ComboBadge({required this.mult});
  final int mult;
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, a) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: a, child: child),
      ),
      child: Container(
        key: ValueKey(mult),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFFFB840)]),
          boxShadow: [BoxShadow(color: kGold.withValues(alpha: .45), blurRadius: 16)],
        ),
        child: Text('x$mult',
            style: const TextStyle(color: Color(0xFF201405), fontSize: 15, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

/// İnce parlayan ilerleme çubuğu
class _GlowBar extends StatelessWidget {
  const _GlowBar({required this.value, required this.color, this.height = 4});
  final double value;
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(children: [
        Container(height: height, color: Colors.white10),
        FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          alignment: Alignment.centerLeft,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withValues(alpha: .55), color]),
              boxShadow: [BoxShadow(color: color.withValues(alpha: .6), blurRadius: 8)],
            ),
          ),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.icon, this.gold = false, this.teal = false});
  final String text;
  final int? icon; // GI indeksi
  final bool gold, teal;
  @override
  Widget build(BuildContext context) {
    final c = gold ? kGold : teal ? kTeal : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xE6121A30), Color(0xE6060B18)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: .28)),
        boxShadow: [BoxShadow(color: c.withValues(alpha: .10), blurRadius: 12)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          GIcon(icon!, size: 15),
          if (text.isNotEmpty) const SizedBox(width: 5),
        ],
        if (text.isNotEmpty)
          Text(text, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: c)),
      ]),
    );
  }
}

// ============================================================================
// ANA MENÜ
// ============================================================================
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key, required this.onPlay, required this.onShop, required this.onMissions, required this.onJournal, required this.onSkins, required this.onSettings});
  final VoidCallback onPlay, onShop, onMissions, onJournal, onSkins, onSettings;

  /// Toplanabilir görev ödülü sayısı — Görevler kartında rozet
  int _claimable() {
    final s = SaveData.I;
    s.ensureToday();
    var n = 0;
    for (final m in todaysMissions()) {
      if (s.missionProgress(m.id) >= m.target && !s.dailyClaimed.contains(m.id)) n++;
    }
    for (final m in missions) {
      if (s.missionProgress(m.id) >= m.target && !s.missionsClaimed.contains(m.id)) n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final s = SaveData.I;
    final nr = nextRank(s.totalDepth);
    final badges = _claimable();
    return Stack(children: [
      const _MenuBg(),
      _Dim(art: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // üst alan arkaplan görselindeki logo/amblem için ayrıldı
            SizedBox(height: MediaQuery.of(context).size.height * .37),

            // rütbe kartı
            _Reveal(
              delay: const Duration(milliseconds: 70),
              child: _Card(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(children: [
                  Row(children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [kTeal.withValues(alpha: .25), kTeal.withValues(alpha: .06)],
                        ),
                        border: Border.all(color: kTeal.withValues(alpha: .35)),
                      ),
                      child: GIcon(GameIcons.rankBadge(s.totalDepth), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('RÜTBE', style: caps(8.5, Colors.white38, spacing: 2.5)),
                        const SizedBox(height: 1),
                        Text(rankFor(s.totalDepth).toUpperCase(),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: kTeal, fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 14)),
                      ]),
                    ),
                    if (nr != null)
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('SONRAKİ', style: caps(8.5, Colors.white38, spacing: 2.5)),
                        const SizedBox(height: 1),
                        Text('${nr.name} · ${nr.meters}m', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w600)),
                      ]),
                  ]),
                  if (nr != null) ...[
                    const SizedBox(height: 9),
                    _GlowBar(value: s.totalDepth / nr.meters, color: kTeal, height: 4),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 10),

            // istatistikler
            _Reveal(
              delay: const Duration(milliseconds: 140),
              child: Row(children: [
                Expanded(child: _StatCard(icon: GI.depth, label: 'EN DERİN', value: '${s.bestDepth} m')),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(icon: GI.lum, label: 'LUM', value: '${s.lum}', color: kGold)),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(iconWidget: _StreakFlame(s.streakDays), label: 'SERİ', value: '${s.streakDays} gün', color: kEmber)),
              ]),
            ),
            const SizedBox(height: 18),

            _Reveal(
              delay: const Duration(milliseconds: 210),
              child: _PlayButton(onTap: onPlay),
            ),
            const SizedBox(height: 16),

            // özellik kartları 2x2
            _Reveal(
              delay: const Duration(milliseconds: 280),
              child: Row(children: [
                Expanded(child: _FeatureCard(icon: GI.upgrade, label: 'Yükseltmeler', sub: 'Işığını güçlendir', color: kGold, onTap: onShop)),
                const SizedBox(width: 10),
                Expanded(child: _FeatureCard(icon: GI.quests, label: 'Görevler', sub: 'Ödül kazan', color: kTeal, badge: badges, onTap: onMissions)),
              ]),
            ),
            const SizedBox(height: 10),
            _Reveal(
              delay: const Duration(milliseconds: 350),
              child: Row(children: [
                Expanded(child: _FeatureCard(icon: GI.book, label: 'Hafıza', sub: 'Hikâyeni oku', color: kViolet, onTap: onJournal)),
                const SizedBox(width: 10),
                Expanded(child: _FeatureCard(icon: GI.skin, label: 'Işıklar', sub: 'Görünüm değiştir', color: kRose, onTap: onSkins)),
              ]),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      ),
      // ayarlar — sağ üst köşe
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 6, right: 12),
          child: Align(
            alignment: Alignment.topRight,
            child: _IconBtn(icon: GI.gear, onTap: onSettings),
          ),
        ),
      ),
    ]);
  }
}

// ============================================================================
// AYARLAR
// ============================================================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.onBack});
  final VoidCallback onBack;
  @override
  State<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  Widget _toggleRow({
    required int icon,
    required String title,
    required String subOn,
    required String subOff,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return _Card(
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [color.withValues(alpha: .22), color.withValues(alpha: .05)],
            ),
            border: Border.all(color: color.withValues(alpha: .3)),
          ),
          child: GIcon(icon, size: 20, opacity: value ? 1 : .4),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          Text(value ? subOn : subOff,
              style: const TextStyle(fontSize: 11, color: Colors.white38)),
        ])),
        Switch(
          value: value,
          activeThumbColor: color,
          activeTrackColor: color.withValues(alpha: .35),
          inactiveThumbColor: Colors.white38,
          inactiveTrackColor: Colors.white10,
          onChanged: onChanged,
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = Sfx.I.muted;
    final haptics = SaveData.I.haptics;
    return _Dim(
      child: _Panel(children: [
        const _PanelHead(icon: GI.gear, title: 'Ayarlar'),
        _toggleRow(
          icon: GI.note,
          title: 'Ses',
          subOn: 'Müzik ve efektler açık',
          subOff: 'Müzik ve efektler kapalı',
          value: !muted, color: kGold,
          onChanged: (_) => setState(() {
            Sfx.I.muted = !Sfx.I.muted;
            SaveData.I.muted = Sfx.I.muted;
            SaveData.I.save();
            Sfx.I.applyMute();
            Sfx.I.play('ui');
          }),
        ),
        const SizedBox(height: 10),
        _toggleRow(
          icon: GI.vibe,
          title: 'Titreşim',
          subOn: 'Dokunsal geri bildirim açık',
          subOff: 'Dokunsal geri bildirim kapalı',
          value: haptics, color: kTeal,
          onChanged: (_) => setState(() {
            SaveData.I.haptics = !SaveData.I.haptics;
            SaveData.I.save();
            SaveData.I.buzz(HapticFeedback.mediumImpact);
          }),
        ),
        const SizedBox(height: 10),
        _Card(
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [kIce.withValues(alpha: .22), kIce.withValues(alpha: .05)],
                ),
                border: Border.all(color: kIce.withValues(alpha: .3)),
              ),
              child: const GIcon(GI.orb, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nasıl Oynanır', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              SizedBox(height: 2),
              Text('Basılı tut: yükselirsin. Bırak: süzülürsün. Duvarlara ve gölgelere değme!',
                  style: TextStyle(fontSize: 11, color: Colors.white38, height: 1.4)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
        Text('GLOWDEEP · v1.0.0', style: caps(10, Colors.white24, spacing: 2)),
        const SizedBox(height: 4),
        _BackBtn(onTap: widget.onBack),
      ]),
    );
  }
}

/// Menü arkaplanı — assets/menu_bg.png varsa onu gösterir,
/// yoksa koyu radyal gradient fallback. Alt yarı UI için karartılır.
class _MenuBg extends StatelessWidget {
  const _MenuBg();
  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      Image.asset(
        'assets/menu_bg.png',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (_, _, _) => Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -.6), radius: 1.2,
              colors: [Color(0xFF1A2450), Color(0xFF0A0F22), kInk],
              stops: [0, .5, 1],
            ),
          ),
        ),
      ),
      // UI'nın geldiği alt bölgeyi karart
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0x5904060D), Color(0xD904060D)],
            stops: [0, .6, .9],
          ),
        ),
      ),
    ]);
  }
}

// ============================================================================
// ÖLÜM EKRANI
// ============================================================================
class DeathScreen extends StatelessWidget {
  const DeathScreen({super.key, required this.stats, required this.canRevive, required this.onRevive, required this.onRetry, required this.onMenu});
  final RunStats stats;
  final bool canRevive;
  final VoidCallback onRevive, onRetry, onMenu;

  @override
  Widget build(BuildContext context) {
    return _Dim(
      child: _Panel(accent: kEmber, children: [
        Container(
          width: 62, height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kEmber.withValues(alpha: .10),
            border: Border.all(color: kEmber.withValues(alpha: .35)),
            boxShadow: [BoxShadow(color: kEmber.withValues(alpha: .18), blurRadius: 26)],
          ),
          child: const GIcon(GI.orb, size: 30, opacity: .85),
        ),
        const SizedBox(height: 12),
        Text('IŞIK SÖNDÜ', style: heading(22, color: kEmber, spacing: 3)),
        const SizedBox(height: 4),
        Text(stats.cause,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.white38, fontStyle: FontStyle.italic)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _StatCard(icon: GI.depth, label: 'DERİNLİK', value: '${stats.depth} m')),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(icon: GI.lum, label: 'KAZANILAN', value: '+${stats.lum}', color: kGold)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _StatCard(icon: GI.trophy, label: 'REKOR', value: '${SaveData.I.bestDepth} m', color: kViolet)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(icon: GI.bolt, label: 'SIYRILIŞ', value: '${stats.nearMisses}', color: kIce)),
        ]),
        if (stats.record) ...[
          const SizedBox(height: 14),
          _Pulse(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(colors: [Color(0x44FFC845), Color(0x1FFFC845)]),
                border: Border.all(color: const Color(0x77FFC845)),
                boxShadow: [BoxShadow(color: kGold.withValues(alpha: .2), blurRadius: 18)],
              ),
              child: Text('YENİ REKOR!', style: heading(13, color: kGold, spacing: 3)),
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (canRevive)
          _PrimaryBtn(icon: GI.torch, text: 'IŞIĞI YAK — 50 ◈', onTap: onRevive),
        _PrimaryBtn(icon: GI.replay, text: 'TEKRAR DENE', onTap: onRetry, dim: canRevive),
        _GhostBtn(icon: GI.share, text: 'Skoru Paylaş',
            onTap: () => SharePlus.instance.share(ShareParams(
                text: 'GLOWDEEP\'te ${stats.depth}m derine indim! Karanlıkta kalan son ışığı sen taşıyabilir misin? #glowdeep'))),
        _TextBtn(text: 'Ana Menü', onTap: onMenu),
      ]),
    );
  }
}

// ============================================================================
// DURAKLATMA
// ============================================================================
class PauseScreen extends StatelessWidget {
  const PauseScreen({super.key, required this.onResume, required this.onQuit});
  final VoidCallback onResume, onQuit;
  @override
  Widget build(BuildContext context) => _Dim(
        child: _Panel(children: [
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .05),
              border: Border.all(color: kLine),
            ),
            child: const GIcon(GI.pause, size: 26, opacity: .7),
          ),
          const SizedBox(height: 12),
          Text('DURAKLATILDI', style: heading(20, spacing: 3)),
          const SizedBox(height: 4),
          const Text('Işığın dinleniyor…', style: TextStyle(fontSize: 12.5, color: Colors.white38, fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          _PrimaryBtn(icon: GI.play, text: 'DEVAM ET', onTap: onResume),
          _GhostBtn(icon: GI.flag, text: 'Yolculuğu Bitir', onTap: onQuit),
        ]),
      );
}

// ============================================================================
// DÜKKAN
// ============================================================================
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.onBack, required this.onToast});
  final VoidCallback onBack;
  final void Function(String, {int icon}) onToast;
  @override
  State<ShopScreen> createState() => _ShopState();
}

const _upgIcons = {
  'light': GI.orb,
  'magnet': GI.magnet,
  'wings': GI.wings,
  'shield': GI.shield,
  'luck': GI.gift,
  'pulse': GI.bolt,
};
const _upgColors = {
  'light': kGold,
  'magnet': kTeal,
  'wings': kIce,
  'shield': kViolet,
  'luck': kRose,
  'pulse': kIce,
};

String _upgNext(String id, int lvl) {
  switch (id) {
    case 'light': return '${lightRadiusFor(lvl).round()} → ${lightRadiusFor(lvl + 1).round()} px ışık';
    case 'magnet': return '${magnetFor(lvl).round()} → ${magnetFor(lvl + 1).round()} px çekim';
    case 'wings': return 'Kontrol +%${((1 - wingsFor(lvl + 1)) * 100).round()}';
    case 'shield': return '+1 kalkan / yolculuk';
    case 'luck': return '+%${(luckFor(lvl + 1) * 100).round()} çift Lum şansı';
    case 'pulse': return '${pulseRadiusFor(lvl).round()}→${pulseRadiusFor(lvl + 1).round()}px, ${pulseCooldownFor(lvl + 1)}sn bekleme';
    default: return '';
  }
}

class _ShopState extends State<ShopScreen> {
  @override
  Widget build(BuildContext context) {
    final s = SaveData.I;
    return _Dim(
      child: _Panel(wide: true, children: [
        _PanelHead(icon: GI.upgrade, title: 'Yükseltmeler', lum: s.lum),
        Expanded(
          child: Scrollbar(
            thumbVisibility: true, thickness: 3, radius: const Radius.circular(3),
            child: ListView(children: [
              for (final u in upgrades)
                _ShopItem(u: u, onBuy: () => setState(() {}),
                    onToast: widget.onToast),
              const SizedBox(height: 4),
            ]),
          ),
        ),
        _BackBtn(onTap: widget.onBack),
      ]),
    );
  }
}

class _ShopItem extends StatelessWidget {
  const _ShopItem({required this.u, required this.onBuy, required this.onToast});
  final Upgrade u;
  final VoidCallback onBuy;
  final void Function(String, {int icon}) onToast;
  @override
  Widget build(BuildContext context) {
    final s = SaveData.I;
    final level = s.upg(u.id);
    final maxed = level >= u.max;
    final cost = maxed ? 0 : u.cost(level);
    final canBuy = !maxed && s.lum >= cost;
    final color = _upgColors[u.id] ?? kGold;
    return _Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [color.withValues(alpha: .22), color.withValues(alpha: .05)],
            ),
            border: Border.all(color: color.withValues(alpha: .3)),
          ),
          child: GIcon(_upgIcons[u.id] ?? GI.orb, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
            Text('Sv.$level', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color.withValues(alpha: .9))),
          ]),
          Text(u.desc, style: const TextStyle(fontSize: 11, color: Colors.white38)),
          const SizedBox(height: 7),
          // seviye pip'leri
          Row(children: [
            for (var i = 0; i < u.max; i++)
              Container(
                width: 12, height: 5,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i < level ? color : Colors.white12,
                  boxShadow: i < level ? [BoxShadow(color: color.withValues(alpha: .5), blurRadius: 4)] : null,
                ),
              ),
          ]),
          if (!maxed) ...[
            const SizedBox(height: 5),
            Text(_upgNext(u.id, level), style: TextStyle(fontSize: 10, color: color.withValues(alpha: .9))),
          ],
        ])),
        const SizedBox(width: 10),
        maxed
            ? const _Tag(text: 'MAX', color: kTeal)
            : _PriceBtn(cost: cost, enabled: canBuy, onTap: () {
                if (s.buyUpgrade(u.id, cost, u.max)) {
                  Sfx.I.play('buy');
                  SaveData.I.buzz(HapticFeedback.lightImpact);
                  onBuy();
                  onToast('${u.name} → Sv.${level + 1}',
                      icon: _upgIcons[u.id] ?? GI.upgrade);
                } else {
                  onToast('Yeterli Lum yok', icon: GI.lock);
                }
              }),
      ]),
    );
  }
}

// ============================================================================
// GÖREVLER
// ============================================================================
class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key, required this.onBack, required this.onToast});
  final VoidCallback onBack;
  final void Function(String, {int icon}) onToast;
  @override
  State<MissionsScreen> createState() => _MisState();
}

class _MisState extends State<MissionsScreen> {
  @override
  Widget build(BuildContext context) {
    final s = SaveData.I;
    return _Dim(
      child: _Panel(wide: true, children: [
        _PanelHead(icon: GI.quests, title: 'Görevler', lum: s.lum),
        Expanded(
          child: Scrollbar(
            thumbVisibility: true, thickness: 3, radius: const Radius.circular(3),
            child: ListView(children: [
              const _Section('BUGÜNÜN GÖREVLERİ', kTeal),
              for (final m in todaysMissions())
                _MissionItem(m: m, daily: true, onChanged: () => setState(() {}),
                    onToast: widget.onToast),
              const SizedBox(height: 8),
              const _Section('KALICI GÖREVLER', Colors.white38),
              for (final m in missions)
                _MissionItem(m: m, onChanged: () => setState(() {}),
                    onToast: widget.onToast),
              const SizedBox(height: 4),
            ]),
          ),
        ),
        _BackBtn(onTap: widget.onBack),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9, left: 2),
        child: Row(children: [
          Container(width: 14, height: 1.5, color: color.withValues(alpha: .5)),
          const SizedBox(width: 7),
          Text(text, style: caps(10.5, color, spacing: 3)),
        ]),
      );
}

class _MissionItem extends StatelessWidget {
  const _MissionItem({required this.m, required this.onChanged, required this.onToast, this.daily = false});
  final Mission m;
  final VoidCallback onChanged;
  final void Function(String, {int icon}) onToast;
  final bool daily;
  @override
  Widget build(BuildContext context) {
    final s = SaveData.I;
    s.ensureToday();
    final prog = s.missionProgress(m.id).clamp(0, m.target);
    final done = daily ? s.dailyClaimed.contains(m.id) : s.missionsClaimed.contains(m.id);
    final ready = prog >= m.target && !done;
    final accent = daily ? kTeal : kGold;
    return _Card(
      margin: const EdgeInsets.only(bottom: 8),
      border: ready ? Border.all(color: accent.withValues(alpha: .55)) : null,
      shadow: ready ? [BoxShadow(color: accent.withValues(alpha: .12), blurRadius: 16)] : null,
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [accent.withValues(alpha: done ? .22 : .14), accent.withValues(alpha: .04)],
            ),
            border: Border.all(color: accent.withValues(alpha: .3)),
          ),
          child: GIcon(done ? GI.check : (daily ? GI.gift : GI.flag),
              size: 20, opacity: done ? 1 : .9),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: done ? Colors.white38 : Colors.white)),
          const SizedBox(height: 2),
          Text(m.desc, style: const TextStyle(fontSize: 11, color: Colors.white38)),
          const SizedBox(height: 7),
          Row(children: [
            Expanded(child: _GlowBar(value: prog / m.target, color: done ? kTeal : accent, height: 4)),
            const SizedBox(width: 8),
            Text('$prog/${m.target}', style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w700)),
          ]),
        ])),
        const SizedBox(width: 10),
        done
            ? const _Tag(text: 'ALINDI')
            : _PriceBtn(cost: m.reward, reward: true, enabled: ready, onTap: () {
                if (daily) {
                  s.dailyClaimed.add(m.id);
                } else {
                  s.missionsClaimed.add(m.id);
                }
                s.lum += m.reward;
                s.save();
                Sfx.I.play('buy');
                SaveData.I.buzz(HapticFeedback.lightImpact);
                onChanged();
                onToast('+${m.reward} ◈ — ${m.title}',
                    icon: daily ? GI.gift : GI.check);
              }),
      ]),
    );
  }
}

// ============================================================================
// HAFIZA (hikâye)
// ============================================================================
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key, required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final s = SaveData.I;
    return Stack(fit: StackFit.expand, children: [
      // derinlik haritası arka planı — 5 bölge dikey kesit
      Image.asset('assets/map_bg.png', fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink()),
      _Dim(
      art: true,
      child: _Panel(wide: true, accent: kViolet, children: [
        const _PanelHead(icon: GI.book, title: 'Hafıza', accent: kViolet),
        // derinlik haritası banner'ı — bölümlerin geçtiği mağara kesiti
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border: Border.all(color: kViolet.withValues(alpha: .25)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(fit: StackFit.expand, children: [
              Image.asset('assets/map_bg.png', fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, _, _) => Container(color: const Color(0xFF0A0F22))),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xB304060D)],
                  ),
                ),
              ),
              Positioned(
                left: 12, bottom: 8,
                child: Text('DERİNLİK HARİTASI', style: caps(9.5, Colors.white54, spacing: 2.5)),
              ),
            ]),
          ),
        ),
        Expanded(
          child: Scrollbar(
            thumbVisibility: true, thickness: 3, radius: const Radius.circular(3),
            child: ListView(children: [
              for (final ch in chapters)
                _JournalItem(ch: ch, seen: s.chaptersSeen.contains(ch.atMeters)),
              const SizedBox(height: 4),
            ]),
          ),
        ),
        _BackBtn(onTap: onBack),
      ]),
      ),
    ]);
  }
}

class _JournalItem extends StatelessWidget {
  const _JournalItem({required this.ch, required this.seen});
  final Chapter ch;
  final bool seen;
  @override
  Widget build(BuildContext context) {
    return _Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: seen ? 1 : .45,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [kViolet.withValues(alpha: seen ? .2 : .08), kViolet.withValues(alpha: .03)],
              ),
              border: Border.all(color: kViolet.withValues(alpha: seen ? .4 : .2)),
            ),
            child: GIcon(seen ? GI.book : GI.lock, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${ch.eyebrow} — ${seen ? ch.name : "???"}',
                style: caps(11, seen ? kViolet : Colors.white38, spacing: 2)),
            const SizedBox(height: 5),
            Text(
              seen ? ch.text : '${ch.atMeters}m derinliğe ulaş',
              style: const TextStyle(fontSize: 13, height: 1.55, fontStyle: FontStyle.italic, color: Colors.white70),
            ),
          ])),
        ]),
      ),
    );
  }
}

// ============================================================================
// IŞIKLAR (skin)
// ============================================================================
class SkinsScreen extends StatefulWidget {
  const SkinsScreen({super.key, required this.onBack, required this.onToast});
  final VoidCallback onBack;
  final void Function(String, {int icon}) onToast;
  @override
  State<SkinsScreen> createState() => _SkinsState();
}

class _SkinsState extends State<SkinsScreen> {
  @override
  Widget build(BuildContext context) {
    final s = SaveData.I;
    return _Dim(
      child: _Panel(wide: true, children: [
        _PanelHead(icon: GI.skin, title: 'Işıklar', lum: s.lum),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.4,
            children: [
              for (final sk in skins)
                _SkinItem(sk: sk, onChanged: () => setState(() {}),
                    onToast: widget.onToast),
            ],
          ),
        ),
        _BackBtn(onTap: widget.onBack),
      ]),
    );
  }
}

class _SkinItem extends StatelessWidget {
  const _SkinItem({required this.sk, required this.onChanged, required this.onToast});
  final Skin sk;
  final VoidCallback onChanged;
  final void Function(String, {int icon}) onToast;
  @override
  Widget build(BuildContext context) {
    final s = SaveData.I;
    final owned = s.ownedSkins.contains(sk.id);
    final sel = s.selSkin == sk.id;
    return _Pressable(
      onTap: () {
        if (owned) {
          s.selSkin = sk.id;
          s.save();
          Sfx.I.play('ui');
          if (!sel) onToast('${sk.name} kuşanıldı', icon: GI.skin);
        } else if (s.lum >= sk.price) {
          s.lum -= sk.price;
          s.ownedSkins.add(sk.id);
          s.selSkin = sk.id;
          s.save();
          Sfx.I.play('buy');
          SaveData.I.buzz(HapticFeedback.lightImpact);
          onToast('${sk.name} açıldı!', icon: GI.skin);
        } else {
          onToast('Yeterli Lum yok', icon: GI.lock);
        }
        onChanged();
      },
      child: _Card(
        border: sel ? Border.all(color: kGold, width: 1.5) : null,
        shadow: sel ? [BoxShadow(color: sk.glow.withValues(alpha: .3), blurRadius: 18)] : null,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [sk.core, sk.glow, sk.glow.withValues(alpha: .15), Colors.transparent], stops: const [0, .5, .75, 1]),
              boxShadow: [BoxShadow(color: sk.glow.withValues(alpha: .55), blurRadius: 16)],
            ),
          ),
          const SizedBox(height: 7),
          Text(sk.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (sel) ...[
              const GIcon(GI.check, size: 12),
              const SizedBox(width: 3),
            ] else if (!owned) ...[
              const GIcon(GI.lum, size: 11),
              const SizedBox(width: 3),
            ],
            Text(
              sel ? 'SEÇİLİ' : owned ? 'açık' : '${sk.price}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: sel ? 1 : 0,
                  color: sel ? kGold : owned ? Colors.white38 : kGoldSoft),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ============================================================================
// BÖLÜM KARTI
// ============================================================================
class ChapterCard extends StatelessWidget {
  const ChapterCard({super.key, required this.chapter, required this.onDone});
  final Chapter chapter;
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xEB02040A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kViolet.withValues(alpha: .10),
                border: Border.all(color: kViolet.withValues(alpha: .35)),
                boxShadow: [BoxShadow(color: kViolet.withValues(alpha: .2), blurRadius: 28)],
              ),
              child: const GIcon(GI.book, size: 26),
            ),
            const SizedBox(height: 16),
            Text(chapter.eyebrow, style: caps(11, kTeal, spacing: 6)),
            const SizedBox(height: 10),
            Text(chapter.name, textAlign: TextAlign.center, style: cinzel(30, color: kGold)),
            const SizedBox(height: 14),
            // süs ayraç
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 34, height: 1, color: kGold.withValues(alpha: .35)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: const GIcon(GI.lum, size: 10, opacity: .8),
              ),
              Container(width: 34, height: 1, color: kGold.withValues(alpha: .35)),
            ]),
            const SizedBox(height: 16),
            Text(chapter.text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.75, fontStyle: FontStyle.italic, color: Colors.white70)),
            const SizedBox(height: 32),
            SizedBox(width: 260, child: _PrimaryBtn(icon: GI.play, text: 'DEVAM ET', onTap: onDone)),
          ]),
        ),
      ),
    );
  }
}

// ============================================================================
// ORTAK BİLEŞENLER
// ============================================================================

/// Dokununca hafifçe küçülen dokunsal sarmalayıcı — tüm tıklanabilirlerde
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? .95 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _down ? .85 : 1,
          duration: const Duration(milliseconds: 110),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Girişte gecikmeli fade + yükselme animasyonu
class _Reveal extends StatefulWidget {
  const _Reveal({required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;
  static const double dy = 16;
  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) c.forward();
      });
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: a,
      builder: (_, child) => Opacity(
        opacity: a.value,
        child: Transform.translate(offset: Offset(0, (1 - a.value) * _Reveal.dy), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Işık Darbesi HUD göstergesi — dolunca parlayan mini rozet
class _PulseHud extends StatelessWidget {
  const _PulseHud({required this.ready});
  final double ready; // 0..1
  @override
  Widget build(BuildContext context) {
    final full = ready >= 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xE6121A30), Color(0xE6060B18)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kGold.withValues(alpha: .15 + .5 * ready)),
        boxShadow: full
            ? [BoxShadow(color: kGold.withValues(alpha: .35), blurRadius: 12)]
            : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        GIcon(GI.orb, size: 14, opacity: .3 + .7 * ready),
        const SizedBox(width: 5),
        SizedBox(
          width: 22,
          child: _GlowBar(value: ready, color: kGold, height: 4),
        ),
      ]),
    );
  }
}

/// Seri alevi — gün değişince elastik pop, seri büyüdükçe alev büyür
class _StreakFlame extends StatelessWidget {
  const _StreakFlame(this.days);
  final int days;
  @override
  Widget build(BuildContext context) {
    final heat = (days / 7).clamp(0.0, 1.0);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      transitionBuilder: (c, a) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
        child: c,
      ),
      child: _Pulse(
        key: ValueKey(days),
        child: GIcon(GI.flame, size: 13 + 6 * heat),
      ),
    );
  }
}

/// Nefes alan parlama animasyonu (rekor rozeti gibi)
class _Pulse extends StatefulWidget {
  const _Pulse({super.key, required this.child});
  final Widget child;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, child) => Transform.scale(
        scale: 1 + CurvedAnimation(parent: c, curve: Curves.easeInOut).value * .06,
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _Dim extends StatelessWidget {
  const _Dim({required this.child, this.art = false});
  final Widget child;
  final bool art;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: art
              // arkaplan görseli üstte görünsün, UI bölgesi koyulaşsın
              ? const [Colors.transparent, Color(0x4004060D), Color(0xD904060D)]
              : const [Color(0xE0040714), Color(0xF202040A)],
          stops: art ? const [0, .6, .92] : null,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children, this.wide = false, this.accent = kGold});
  final List<Widget> children;
  final bool wide;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: wide ? 430 : 380, maxHeight: h * .92),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          width: double.infinity,
          height: wide ? h * .84 : null,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xF7141C38), Color(0xF7080B1A)],
            ),
            border: Border.all(color: accent.withValues(alpha: .18)),
            boxShadow: [
              const BoxShadow(color: Colors.black87, blurRadius: 60),
              BoxShadow(color: accent.withValues(alpha: .06), blurRadius: 40),
            ],
          ),
          child: Stack(children: [
            Column(mainAxisSize: MainAxisSize.min, children: children),
            // üstte vurgu çizgisi
            Positioned(
              top: 0, left: 40, right: 40, height: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent, accent.withValues(alpha: .7), Colors.transparent,
                  ]),
                  boxShadow: [BoxShadow(color: accent.withValues(alpha: .5), blurRadius: 14)],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.margin, this.padding, this.border, this.shadow});
  final Widget child;
  final EdgeInsets? margin, padding;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0x14FFFFFF), Color(0x08FFFFFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: border ?? Border.all(color: kLine),
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}

class _PanelHead extends StatelessWidget {
  const _PanelHead({required this.title, this.lum, this.icon, this.accent = kGold});
  final String title;
  final int? lum;
  final int? icon; // GI indeksi
  final Color accent;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        if (icon != null) ...[
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: accent.withValues(alpha: .12),
              border: Border.all(color: accent.withValues(alpha: .3)),
            ),
            child: GIcon(icon!, size: 19),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(title, overflow: TextOverflow.ellipsis, style: heading(17, spacing: 1)),
        ),
        const Spacer(),
        if (lum != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(colors: [Color(0x24FFC845), Color(0x0FFFC845)]),
              border: Border.all(color: const Color(0x40FFC845)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const GIcon(GI.lum, size: 13),
              const SizedBox(width: 4),
              Text('$lum', style: const TextStyle(color: kGold, fontWeight: FontWeight.w800, fontSize: 14)),
            ]),
          ),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.icon, this.iconWidget, this.color = Colors.white});
  final String label, value;
  final int? icon; // GI indeksi
  final Widget? iconWidget; // verilirse icon yerine bu kullanılır
  final Color color;
  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (icon != null || iconWidget != null) ...[
            iconWidget ?? GIcon(icon!, size: 13),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: caps(9, Colors.white38, spacing: 1.8)),
          ),
        ]),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, maxLines: 1,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ),
      ]),
    );
  }
}

/// Büyük parlayan ana buton (menüdeki PLAY) — parlak süpürme efekti
class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_PlayButton> createState() => _PlayBtnState();
}

class _PlayBtnState extends State<_PlayButton> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, _) {
        final v = c.value; // süpürme pozisyonu
        final glow = (math.sin(v * math.pi * 2) + 1) / 2; // nefes alan parlama
        return _Pressable(
          onTap: widget.onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 17),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFE08A), Color(0xFFFFA62B)],
                  ),
                  boxShadow: [
                    BoxShadow(color: kGold.withValues(alpha: .28 + .2 * glow), blurRadius: 26 + 16 * glow),
                    const BoxShadow(color: Color(0xFF8A5A10), offset: Offset(0, 4)),
                  ],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  // ikon orijinal rengiyle — kontrast için koyu yuvada
                  Container(
                    width: 32, height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF201405),
                    ),
                    child: const Center(child: GIcon(GI.play, size: 20)),
                  ),
                  const SizedBox(width: 8),
                  Text('YOLCULUĞA BAŞLA',
                      style: heading(15, color: const Color(0xFF201405), spacing: 2.5, w: FontWeight.w900)),
                ]),
              ),
              // soldan sağa geçen parlak bant
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.white.withValues(alpha: .25), Colors.transparent],
                        stops: [
                          (v * 1.4 - .3).clamp(0.0, 1.0),
                          (v * 1.4 - .15).clamp(0.0, 1.0),
                          (v * 1.4).clamp(0.0, 1.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({required this.text, required this.onTap, this.icon, this.dim = false});
  final String text;
  final VoidCallback onTap;
  final int? icon; // GI indeksi
  final bool dim;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Pressable(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: dim
                ? const LinearGradient(colors: [Color(0xFF262C42), Color(0xFF181D2E)])
                : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFE08A), Color(0xFFFFB840)]),
            border: dim ? Border.all(color: kLine) : null,
            boxShadow: dim ? null : const [BoxShadow(color: Color(0x33FFB840), blurRadius: 22, offset: Offset(0, 4))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[
              dim
                  ? GIcon(icon!, size: 19, opacity: .6)
                  : Container(
                      width: 26, height: 26,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Color(0xFF201405)),
                      child: Center(child: GIcon(icon!, size: 16)),
                    ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2,
                      color: dim ? Colors.white60 : const Color(0xFF201405))),
            ),
          ]),
        ),
      ),
    );
  }
}

class _GhostBtn extends StatelessWidget {
  const _GhostBtn({required this.text, required this.onTap, this.icon});
  final String text;
  final VoidCallback onTap;
  final int? icon; // GI indeksi
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Pressable(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0x0FFFFFFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kLine),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[GIcon(icon!, size: 17, opacity: .85), const SizedBox(width: 6)],
            Flexible(
              child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TextBtn extends StatelessWidget {
  const _TextBtn({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onTap, child: Text(text, style: const TextStyle(color: Colors.white38, letterSpacing: 1)));
  }
}

class _BackBtn extends StatelessWidget {
  const _BackBtn({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _Pressable(
        onTap: onTap,
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GIcon(GI.back, size: 14, tint: Colors.white38),
          SizedBox(width: 2),
          Text('Geri', style: TextStyle(color: Colors.white38, fontSize: 14, letterSpacing: 1)),
        ]),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final int icon; // GI indeksi
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0x1FFFFFFF), Color(0x0AFFFFFF)],
          ),
          border: Border.all(color: kLine),
        ),
        child: GIcon(icon, size: 22),
      ),
    );
  }
}

class _PriceBtn extends StatelessWidget {
  const _PriceBtn({required this.cost, required this.enabled, required this.onTap, this.reward = false});
  final int cost;
  final bool enabled, reward;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: enabled ? onTap : () {},
      child: Opacity(
        opacity: enabled ? 1 : .6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: enabled
                ? LinearGradient(colors: reward ? const [Color(0xFF7FF5E0), kTeal] : const [Color(0xFFFFE08A), Color(0xFFFFB840)])
                : null,
            color: enabled ? null : const Color(0x10FFFFFF),
            border: enabled ? null : Border.all(color: kLine),
            boxShadow: enabled ? [BoxShadow(color: (reward ? kTeal : kGold).withValues(alpha: .3), blurRadius: 12)] : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            GIcon(GI.lum, size: 12, tint: enabled ? const Color(0xFF201405) : Colors.white24),
            const SizedBox(width: 4),
            Text(reward ? '+$cost' : '$cost',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: enabled ? const Color(0xFF201405) : Colors.white24)),
          ]),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.color = kTeal});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: .15),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color, letterSpacing: 1)),
    );
  }
}

/// Menüdeki özellik kartı (ikon + başlık + alt açıklama + isteğe bağlı rozet)
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.label, required this.sub, required this.color, required this.onTap, this.badge = 0});
  final int icon; // GI indeksi
  final String label, sub;
  final Color color;
  final VoidCallback onTap;
  final int badge;
  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: _Card(
        child: Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [color.withValues(alpha: .22), color.withValues(alpha: .05)],
                ),
                border: Border.all(color: color.withValues(alpha: .3)),
              ),
              child: GIcon(icon, size: 22),
            ),
            if (badge > 0)
              Positioned(
                top: -5, right: -5,
                child: Container(
                  width: 17, height: 17,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kDanger,
                    border: Border.all(color: kInk, width: 2),
                    boxShadow: [BoxShadow(color: kDanger.withValues(alpha: .5), blurRadius: 8)],
                  ),
                  child: Text('$badge', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
          ]),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label, maxLines: 1, softWrap: false,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, color: Colors.white38)),
          ])),
          const SizedBox(width: 4),
          GIcon(GI.back, flip: true, tint: color.withValues(alpha: .5), size: 15),
        ]),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.msg, this.icon = GI.lum});
  final String msg;
  final int icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xF2141C38), Color(0xF2080B1A)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x3DFFC845)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        GIcon(icon, size: 15),
        const SizedBox(width: 8),
        Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFFFFE9A8))),
      ]),
    );
  }
}
