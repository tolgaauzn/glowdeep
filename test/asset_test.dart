import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/sprite.dart';
import 'package:flame/components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('player.png sprite sheet yükleniyor ve 6 kareye dilimleniyor', () async {
    final data = await rootBundle.load('assets/images/player.png');
    final img = await decodeImageFromList(data.buffer.asUint8List());
    expect(img.width, 2172);
    expect(img.height, 724);
    final sheet = SpriteSheet(image: img, srcSize: Vector2(362, 724));
    final f = sheet.getSprite(0, 5);
    expect(f.srcSize.x, 362);
  });
}
