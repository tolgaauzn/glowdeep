import 'dart:math';
import 'dart:ui';

/// ---------------------------------------------------------------------------
/// GLOWDEEP — tüm oyun verisi: bölgeler, hikâye, yükseltmeler, görevler, ışıklar
/// ---------------------------------------------------------------------------

class Zone {
  final String name;
  final int atMeters;
  final Color wall;
  final Color edge;
  final Color bgTop;
  final Color bgBottom;
  final Color accent;
  const Zone({
    required this.name,
    required this.atMeters,
    required this.wall,
    required this.edge,
    required this.bgTop,
    required this.bgBottom,
    required this.accent,
  });
}

const zones = <Zone>[
  Zone(
    name: 'Yankı Mağarası',
    atMeters: 0,
    wall: Color(0xFF0E2438),
    edge: Color(0xFF2E6E7E),
    bgTop: Color(0xFF030711),
    bgBottom: Color(0xFF071522),
    accent: Color(0xFF37E0C8),
  ),
  Zone(
    name: 'Kristal Damarları',
    atMeters: 400,
    wall: Color(0xFF1E1740),
    edge: Color(0xFF5B3FA8),
    bgTop: Color(0xFF080614),
    bgBottom: Color(0xFF140F2E),
    accent: Color(0xFFA06BFF),
  ),
  Zone(
    name: 'Uyuyan Derinlik',
    atMeters: 1000,
    wall: Color(0xFF0C1633),
    edge: Color(0xFF2A4AA0),
    bgTop: Color(0xFF030512),
    bgBottom: Color(0xFF0A1230),
    accent: Color(0xFF4D7CFF),
  ),
  Zone(
    name: 'Küller Vadisi',
    atMeters: 1700,
    wall: Color(0xFF301408),
    edge: Color(0xFF8A4A20),
    bgTop: Color(0xFF0E0605),
    bgBottom: Color(0xFF23100A),
    accent: Color(0xFFFF8A3D),
  ),
  Zone(
    name: 'Göğün Dibi',
    atMeters: 2600,
    wall: Color(0xFF241433),
    edge: Color(0xFF7A5A2E),
    bgTop: Color(0xFF0A0714),
    bgBottom: Color(0xFF1E1430),
    accent: Color(0xFFFFD66B),
  ),
];

/// İki bölge arasında renklerin yumuşak geçişi
class ZoneBlend {
  static const double blendMeters = 140;
  static Zone at(double depth) {
    if (depth >= zones.last.atMeters) return zones.last;
    int i = 0;
    for (; i < zones.length - 1; i++) {
      if (depth < zones[i + 1].atMeters) break;
    }
    final a = zones[i];
    final b = zones[i + 1];
    double t = (depth - b.atMeters + blendMeters) / blendMeters;
    t = t.clamp(0.0, 1.0);
    if (t <= 0) return a;
    return Zone(
      name: t < .5 ? a.name : b.name,
      atMeters: a.atMeters,
      wall: Color.lerp(a.wall, b.wall, t)!,
      edge: Color.lerp(a.edge, b.edge, t)!,
      bgTop: Color.lerp(a.bgTop, b.bgTop, t)!,
      bgBottom: Color.lerp(a.bgBottom, b.bgBottom, t)!,
      accent: Color.lerp(a.accent, b.accent, t)!,
    );
  }

  /// Mevcut bölge indeksi (geçişten bağımsız)
  static int indexAt(double depth) {
    int i = 0;
    for (; i < zones.length - 1; i++) {
      if (depth < zones[i + 1].atMeters) break;
    }
    return i;
  }
}

/// ---------------------------------------------------------------------------
/// HİKÂYE — Hafıza parçaları (tamamen özgün)
/// ---------------------------------------------------------------------------
class Chapter {
  final int atMeters;
  final String eyebrow;
  final String name;
  final String text;
  const Chapter(this.atMeters, this.eyebrow, this.name, this.text);
}

const chapters = <Chapter>[
  Chapter(0, 'BAŞLANGIÇ', 'Son Kıvılcım',
      'Dünya karardığında, Büyük Işık bin parçaya bölündü. Son parça, küçük bir ışık ruhunun kalbinde saklandı: Lumora. Fener\'e ulaşana dek içindeki közü taşıyacak.'),
  Chapter(400, 'BÖLÜM I', 'Kristal Damarları',
      'Mağaranın damarlarında donmuş ışık var. Kristaller bir zamanlar gökyüzünün parçalarıydı — şimdi gölge onları kendine çekiyor.'),
  Chapter(1000, 'BÖLÜM II', 'Uyuyan Derinlik',
      'Burada karanlık uyur değil — dinler. Gölge güveleri ışığın peşinde. Lumora nefesini tuttu ve süzüldü.'),
  Chapter(1700, 'BÖLÜM III', 'Küller Vadisi',
      'Yanmış bir dünyanın külleri. Eskiden burada bir şehir varmış; fenerler, şarkılar, sabahlar. Küllerin altında hâlâ sıcak bir şeyler var.'),
  Chapter(2600, 'BÖLÜM IV', 'Göğün Dibi',
      'Karanlık inceliyor. Yukarıda bir yerlerde Gökyüzü Feneri bekliyor — söndürülmüş ama kırılmamış. Tıpkı Lumora gibi.'),
  Chapter(3400, 'BÖLÜM V', 'Fısıltı Merdiveni',
      'Duyduğu sesler gerçek değil — karanlığın hatıraları. Ama bir tanesi farklı: "Devam et." Kendi sesi.'),
  Chapter(4500, 'BÖLÜM VI', 'Kırık Ay',
      'Ay\'ın bir parçası buraya düşmüş. Lumora ona dokundu ve içindeki köz biraz daha büyüdü.'),
  Chapter(6000, 'BÖLÜM VII', 'Sessiz Koro',
      'Binlerce küçük ışık uykuda. Lumora geçerken hepsi bir anlığına gözlerini açtı. Yalnız değildi.'),
  Chapter(8000, 'BÖLÜM VIII', 'Son Merdiven',
      'Karanlık artık direnmiyor — izliyor. Çünkü biliyor: bu kıvılcım sönmeyecek.'),
  Chapter(12000, 'SON', 'Gökyüzü Feneri',
      'Fener\'e dokundu. Işık önce bir nokta, sonra bir sel oldu. Dünya yeniden doğmadı — ama yeniden hatırlandı. Ve bu, her şeyi değiştirdi.'),
];

/// ---------------------------------------------------------------------------
/// YÜKSELTMELER
/// ---------------------------------------------------------------------------
class Upgrade {
  final String id;
  final String icon;
  final String name;
  final String desc;
  final int max;
  final int Function(int level) cost;
  const Upgrade({
    required this.id,
    required this.icon,
    required this.name,
    required this.desc,
    required this.max,
    required this.cost,
  });
}

const upgrades = <Upgrade>[
  Upgrade(id: 'light', icon: '◉', name: 'Işık Halkası', desc: 'Karanlığı daha uzağa aydınlat', max: 8, cost: _costLight),
  Upgrade(id: 'magnet', icon: '◈', name: 'Derin Mıknatıs', desc: 'Lumları kendine çek', max: 8, cost: _costMagnet),
  Upgrade(id: 'wings', icon: '❖', name: 'Hafif Kanatlar', desc: 'Daha yumuşak, kontrollü süzülüş', max: 5, cost: _costWings),
  Upgrade(id: 'shield', icon: '⛉', name: 'Koruyucu Pelerin', desc: 'Her yolculukta ekstra can', max: 3, cost: _costShield),
  Upgrade(id: 'luck', icon: '✦', name: 'Şanslı Öz', desc: 'Lumların çift gelme şansı', max: 5, cost: _costLuck),
  Upgrade(id: 'pulse', icon: '✺', name: 'Işık Darbesi', desc: 'Çift dokunuş: yakın gölgeleri dağıtır', max: 3, cost: _costPulse),
];

int _costLight(int l) => 40 + 55 * l;
int _costMagnet(int l) => 35 + 50 * l;
int _costWings(int l) => 60 + 80 * l;
int _costShield(int l) => 120 + 140 * l;
int _costLuck(int l) => 90 + 100 * l;
int _costPulse(int l) => 150 + 160 * l;

double lightRadiusFor(int lvl) => 95.0 + 16 * lvl;
double magnetFor(int lvl) => 55.0 + 22 * lvl;
double wingsFor(int lvl) => 1.0 - 0.05 * lvl; // fizik çarpanı
int shieldFor(int lvl) => lvl;
double luckFor(int lvl) => 0.08 * lvl;
double pulseRadiusFor(int lvl) => 150.0 + 45 * lvl;   // 195 → 285
double pulseCooldownFor(int lvl) => 9.0 - 1.5 * lvl;  // 7.5s → 4.5s

/// ---------------------------------------------------------------------------
/// IŞIKLAR (görünümler)
/// ---------------------------------------------------------------------------
class Skin {
  final String id;
  final String name;
  final int price; // 0 = ücretsiz
  final Color core;
  final Color glow;
  const Skin(this.id, this.name, this.price, this.core, this.glow);
}

const skins = <Skin>[
  Skin('ember', 'Köz', 0, Color(0xFFFFF6D8), Color(0xFFFFC84D)),
  Skin('moon', 'Ay Işığı', 150, Color(0xFFF0FEFF), Color(0xFF7FF5FF)),
  Skin('violet', 'Menekşe Rüyası', 300, Color(0xFFF6EEFF), Color(0xFFB78BFF)),
  Skin('dawn', 'Şafak', 450, Color(0xFFFFF0F4), Color(0xFFFF9DB4)),
  Skin('moss', 'Yosun', 600, Color(0xFFF4FFE8), Color(0xFFA8FF7A)),
  Skin('stardust', 'Yıldız Tozu', 1200, Color(0xFFFFFFFF), Color(0xFF9CC8FF)),
];

/// ---------------------------------------------------------------------------
/// RÜTBELER — toplam derinliğe göre unvan
/// ---------------------------------------------------------------------------
class Rank {
  final int meters;
  final String name;
  const Rank(this.meters, this.name);
}

const ranks = <Rank>[
  Rank(0, 'Tohum'),
  Rank(500, 'Kıvılcım'),
  Rank(1500, 'Meşale'),
  Rank(3500, 'Fener Taşıyıcı'),
  Rank(7000, 'Şafak Habercisi'),
  Rank(12000, 'Küllerin Efendisi'),
  Rank(25000, 'Güneş'),
];

int rankIndexFor(int totalMeters) {
  var i = 0;
  for (var k = 0; k < ranks.length; k++) {
    if (totalMeters >= ranks[k].meters) i = k;
  }
  return i;
}

String rankFor(int totalMeters) => ranks[rankIndexFor(totalMeters)].name;

Rank? nextRank(int totalMeters) {
  for (final k in ranks) {
    if (totalMeters < k.meters) return k;
  }
  return null;
}

/// ---------------------------------------------------------------------------
/// GÖREVLER
/// ---------------------------------------------------------------------------
class Mission {
  final String id;
  final String title;
  final String desc;
  final int target;
  final int reward;
  const Mission(this.id, this.title, this.desc, this.target, this.reward);
}

const missions = <Mission>[
  Mission('first_flight', 'İlk Uçuş', 'İlk yolculuğunu tamamla', 1, 25),
  Mission('depth_100', 'Kıvılcım', 'Tek yolculukta 100m in', 100, 40),
  Mission('depth_500', 'Mağara Yürüyüşçüsü', 'Tek yolculukta 500m in', 500, 100),
  Mission('depth_1500', 'Derinlerin Sesi', 'Tek yolculukta 1500m in', 1500, 250),
  Mission('total_5000', 'Yorulmaz', 'Toplam 5.000m uç', 5000, 80),
  Mission('total_25000', 'Karanlık Yoldaşı', 'Toplam 25.000m uç', 25000, 300),
  Mission('lum_500', 'Işık Toplayıcı', 'Toplam 500 Lum kazan', 500, 60),
  Mission('lum_3000', 'Hazine Kalfası', 'Toplam 3.000 Lum kazan', 3000, 200),
  Mission('near_10', 'Uçarı', 'Tehlikelere 10 kez sıyırarak geç', 10, 70),
  Mission('run_lum_40', 'Bereketli Uçuş', 'Tek yolculukta 40 Lum topla', 40, 60),
  Mission('revive_1', 'Sönmeyen', 'Bir kez yeniden alevlen', 1, 50),
  Mission('upg_5', 'Güçlenen Işık', '5 yükseltme satın al', 5, 80),
  Mission('zone_3', 'Küllere Ulaşan', 'Küller Vadisi\'ne ulaş', 3, 150),
  Mission('zone_5', 'Göğe Dokunan', 'Göğün Dibi\'ne ulaş', 5, 400),
];

/// Günlük görev havuzu — her gün günün tohumuyla 3 tanesi seçilir
/// (herkes aynı gün aynı görevleri görür)
const dailyPool = <Mission>[
  Mission('d_runs', 'Günlük Isınma', 'Bugün 3 yolculuk yap', 3, 40),
  Mission('d_runs5', 'Karanlık Maratonu', 'Bugün 5 yolculuk yap', 5, 70),
  Mission('d_lum', 'Günlük Toplayıcı', 'Bugün toplam 250 Lum kazan', 250, 50),
  Mission('d_lum400', 'Lum Yağmuru', 'Bugün toplam 400 Lum kazan', 400, 85),
  Mission('d_depth', 'Günlük Dalış', 'Bugün tek yolculukta 300m in', 300, 60),
  Mission('d_depth500', 'Derin Nefes', 'Bugün tek yolculukta 500m in', 500, 95),
  Mission('d_near', 'Bıçak Sırtı', 'Bugün tehlikelere 8 kez sıyırarak geç', 8, 60),
  Mission('d_runlum', 'Bereketli Av', 'Bugün tek yolculukta 50 Lum topla', 50, 60),
  Mission('d_total', 'Uzun Yürüyüş', 'Bugün toplam 1.500m uç', 1500, 70),
  Mission('d_combo', 'Kesintisiz Ritim', 'Bugün 12\'lik kombo zinciri yap', 12, 55),
];

/// Bugünün 3 görevi — gün değişince liste değişir
List<Mission> todaysMissions() {
  final d = DateTime.now();
  final seed = d.year * 10000 + d.month * 100 + d.day;
  final pool = [...dailyPool]..shuffle(Random(seed));
  return pool.take(3).toList();
}
