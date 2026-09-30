import 'package:flutter_test/flutter_test.dart';
import 'package:glowdeep/data.dart';

void main() {
  test('ekonomi ve bölge verileri tutarlı', () {
    // yükseltme maliyetleri pozitif ve artan
    for (final u in upgrades) {
      for (var l = 0; l < u.max; l++) {
        expect(u.cost(l), greaterThan(0));
        if (l > 0) expect(u.cost(l), greaterThanOrEqualTo(u.cost(l - 1)));
      }
    }
    // bölgeler artan derinlikte
    for (var i = 1; i < zones.length; i++) {
      expect(zones[i].atMeters, greaterThan(zones[i - 1].atMeters));
    }
    // bölüm geçişi pürüzsüz
    expect(ZoneBlend.indexAt(0), 0);
    expect(ZoneBlend.indexAt(500), 1);
    expect(ZoneBlend.indexAt(99999), zones.length - 1);
    // görev ödülleri pozitif
    for (final m in missions) {
      expect(m.reward, greaterThan(0));
      expect(m.target, greaterThan(0));
    }
    // varsayılan skin ücretsiz
    expect(skins.first.price, 0);
  });
}
