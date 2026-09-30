import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Kalıcı kayıt — tüm ilerleme tek JSON blobunda tutulur.
class SaveData {
  static const _key = 'glowdeep_save_v1';
  static final SaveData I = SaveData._();
  SaveData._();

  int lum = 0;
  int bestDepth = 0;
  int totalDepth = 0;
  int totalLum = 0;
  int runs = 0;
  int revives = 0;
  int nearMisses = 0;
  int bestRunLum = 0;
  int upgradesBought = 0;
  int maxZone = 1;
  Map<String, int> upgradeLevels = {};
  Set<String> ownedSkins = {'ember'};
  String selSkin = 'ember';
  Set<String> missionsClaimed = {};
  Set<int> chaptersSeen = {0};
  bool muted = false;
  bool haptics = true;
  bool tutorialDone = false;
  int streakDays = 0;
  String lastDay = '';   // yyyy-mm-dd
  int lastTs = 0;        // epoch seconds (AFK ödülü için)
  // günlük görev sayaçları
  String msDay = '';
  int dayRuns = 0;
  int dayLum = 0;
  int dayDepthBest = 0;
  int dayNear = 0;        // bugünkü toplam sıyrılış
  int dayBestRunLum = 0;  // bugün tek yolculukta en çok lum
  int dayTotal = 0;       // bugünkü toplam metre
  int dayBestCombo = 0;   // bugünkü en yüksek kombo
  Set<String> dailyClaimed = {};

  late SharedPreferences _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final raw = _p.getString(_key);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      lum = j['lum'] ?? 0;
      bestDepth = j['bestDepth'] ?? 0;
      totalDepth = j['totalDepth'] ?? 0;
      totalLum = j['totalLum'] ?? 0;
      runs = j['runs'] ?? 0;
      revives = j['revives'] ?? 0;
      nearMisses = j['nearMisses'] ?? 0;
      bestRunLum = j['bestRunLum'] ?? 0;
      upgradesBought = j['upgBought'] ?? 0;
      maxZone = j['maxZone'] ?? 1;
      upgradeLevels = Map<String, int>.from(j['upg'] ?? {});
      ownedSkins = Set<String>.from(j['skins'] ?? ['ember']);
      selSkin = j['selSkin'] ?? 'ember';
      missionsClaimed = Set<String>.from(j['claimed'] ?? []);
      chaptersSeen = Set<int>.from(j['chapters'] ?? [0]);
      muted = j['muted'] ?? false;
      haptics = j['haptics'] ?? true;
      tutorialDone = j['tutorial'] ?? false;
      streakDays = j['streak'] ?? 0;
      lastDay = j['lastDay'] ?? '';
      lastTs = j['lastTs'] ?? 0;
      msDay = j['msDay'] ?? '';
      dayRuns = j['dayRuns'] ?? 0;
      dayLum = j['dayLum'] ?? 0;
      dayDepthBest = j['dayDepth'] ?? 0;
      dayNear = j['dayNear'] ?? 0;
      dayBestRunLum = j['dayBRL'] ?? 0;
      dayTotal = j['dayTotal'] ?? 0;
      dayBestCombo = j['dayCombo'] ?? 0;
      dailyClaimed = Set<String>.from(j['dclaimed'] ?? []);
      ensureToday();
    } catch (_) {/* bozuk kayıt → sıfırdan başla */}
  }

  void save() {
    lastTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _p.setString(_key, jsonEncode({
      'lum': lum, 'bestDepth': bestDepth, 'totalDepth': totalDepth,
      'totalLum': totalLum, 'runs': runs, 'revives': revives,
      'nearMisses': nearMisses, 'bestRunLum': bestRunLum,
      'upgBought': upgradesBought, 'maxZone': maxZone,
      'upg': upgradeLevels, 'skins': ownedSkins.toList(),
      'selSkin': selSkin, 'claimed': missionsClaimed.toList(),
      'chapters': chaptersSeen.toList(), 'muted': muted,
      'haptics': haptics,
      'tutorial': tutorialDone,
      'streak': streakDays, 'lastDay': lastDay, 'lastTs': lastTs,
      'msDay': msDay, 'dayRuns': dayRuns, 'dayLum': dayLum,
      'dayDepth': dayDepthBest, 'dclaimed': dailyClaimed.toList(),
      'dayNear': dayNear, 'dayBRL': dayBestRunLum,
      'dayTotal': dayTotal, 'dayCombo': dayBestCombo,
    }));
  }

  int upg(String id) => upgradeLevels[id] ?? 0;

  /// Titreşim açıksa çalıştır — örn. save.buzz(HapticFeedback.lightImpact)
  void buzz(Future<void> Function() haptic) {
    if (haptics) haptic();
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// Gün değiştiyse günlük sayaçları sıfırla
  void ensureToday() {
    final t = _today();
    if (msDay != t) {
      msDay = t;
      dayRuns = 0;
      dayLum = 0;
      dayDepthBest = 0;
      dayNear = 0;
      dayBestRunLum = 0;
      dayTotal = 0;
      dayBestCombo = 0;
      dailyClaimed = {};
    }
  }

  bool buyUpgrade(String id, int cost, int max) {
    final l = upg(id);
    if (l >= max || lum < cost) return false;
    lum -= cost;
    upgradeLevels[id] = l + 1;
    upgradesBought++;
    save();
    return true;
  }

  /// Günlük ödül — döndürürse ödül miktarı, yoksa 0
  int claimDaily() {
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    if (lastDay == today) return 0;
    final yesterday = now.subtract(const Duration(days: 1));
    final yStr = '${yesterday.year}-${yesterday.month}-${yesterday.day}';
    streakDays = (lastDay == yStr) ? streakDays + 1 : 1;
    lastDay = today;
    // her 7. gün katlanan milestone bonusu: 7g→+75, 14g→+150, 21g→+225...
    final reward = 25 + 10 * streakDays +
        (streakDays % 7 == 0 ? 75 * (streakDays ~/ 7) : 0);
    lum += reward;
    save();
    return reward;
  }

  /// AFK ödülü — "Derin Yankı": yokken biriken Lum (dakika başına 0.5, max 3 saat)
  int claimIdle() {
    if (lastTs == 0) return 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final mins = (now - lastTs) ~/ 60;
    if (mins < 10) return 0;
    final reward = (mins.clamp(0, 180) * 0.5).floor();
    if (reward <= 0) return 0;
    lum += reward;
    save();
    return reward;
  }

  int missionProgress(String id) {
    switch (id) {
      case 'first_flight': return runs;
      case 'depth_100':
      case 'depth_500':
      case 'depth_1500': return bestDepth;
      case 'total_5000':
      case 'total_25000': return totalDepth;
      case 'lum_500':
      case 'lum_3000': return totalLum;
      case 'near_10': return nearMisses;
      case 'run_lum_40': return bestRunLum;
      case 'revive_1': return revives;
      case 'upg_5': return upgradesBought;
      case 'zone_3':
      case 'zone_5': return maxZone;
      case 'd_runs':
      case 'd_runs5': return dayRuns;
      case 'd_lum':
      case 'd_lum400': return dayLum;
      case 'd_depth':
      case 'd_depth500': return dayDepthBest;
      case 'd_near': return dayNear;
      case 'd_runlum': return dayBestRunLum;
      case 'd_total': return dayTotal;
      case 'd_combo': return dayBestCombo;
      default: return 0;
    }
  }
}
