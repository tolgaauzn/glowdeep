# GLOWDEEP — Karanlıkta Kalan Işık

Dünyanın son ışık kıvılcımını taşıyan Lumora'yı, sonsuz karanlık mağaralardan geçirerek
Gökyüzü Feneri'ne ulaştırdığın tek-parmak bir uçuş/kaçınma oyunu.

**Teknoloji:** Flutter 3.47 + Flame 1.38 oyun motoru · Dart · Native ARM derlemesi
(WebView değil — gerçek native uygulama)

---

## Oyun Özellikleri

- **Tek parmak kontrol:** Basılı tut = yüksel, bırak = süzül
- **Işık/karanlık mekaniği:** Sadece ışık halkan kadar görürsün — ışığı büyütmek oyunun kalbi
- **5 bölge + 10 hikâye bölümü:** Yankı Mağarası → Kristal Damarları → Uyuyan Derinlik → Küller Vadisi → Göğün Dibi ve sonsuz devam
- **Lum ekonomisi:** Topla → yükseltme al → daha derine in (bağımlılık döngüsü)
- **5 yükseltme:** Işık Halkası, Derin Mıknatıs, Hafif Kanatlar, Koruyucu Pelerin, Şanslı Öz
- **14 görev, 6 ışık görünümü, günlük ödül serisi, AFK "Derin Yankı" geliri**
- **Sıyrılış bonusu:** Tehlikelerin dibinden geç → ekstra Lum
- **%100 prosedürel:** Tüm grafik ve sesler kodla üretilir — asset dosyası yok, boyut minimal, telif riski sıfır

## Proje Yapısı

```
lib/
  main.dart            — uygulama girişi + tüm ekranlar (menü, dükkan, görevler, hafıza, ışıklar)
  data.dart            — bölgeler, hikâye metinleri, yükseltme/görev/skin tanımları
  save.dart            — kalıcı kayıt (SharedPreferences)
  audio.dart           — prosedürel ses sentezi (WAV üretimi çalışma zamanında)
  game/
    glowdeep_game.dart — ana oyun döngüsü: fizik, spawn, çarpışma, skor
    tunnel.dart        — prosedürel mağara tüneli üretimi + çizim
    entities.dart      — Orb (Lum), Crystal, Moth
    player.dart        — Lumora karakteri
    background.dart    — paralaks arka plan katmanları
    darkness.dart      — karanlık perdesi + parlama katmanı
    fx.dart            — parçacıklar, uçan yazılar, ekran sarsıntısı
tool/make_icon.js      — ikon üreteci (node tool/make_icon.js)
```

## Geliştirme

```bash
# Flutter'ı PATH'e ekle (tek seferlik, sistem ayarlarından veya her oturumda):
export PATH="/c/flutter/bin:$PATH"

# Bağımlılıklar
flutter pub get

# Emülatörde çalıştır (hot reload aktif — kodu değiştir, 'r' bas)
flutter run -d emulator-5554

# Windows'ta hızlı test
flutter run -d windows

# Analiz + test
flutter analyze
flutter test
```

## Test (Android Studio ile)

1. Android Studio → **Open** → `C:\Users\tolga\Desktop\Oyun` klasörü
2. Üst barda cihaz olarak **Pixel_6** emülatörünü seç (yoksa Device Manager'dan oluştur)
3. ▶ Run — veya terminalde `flutter run`

Kendi telefonunda: Geliştirici Seçenekleri → USB Hata Ayıklama → kablo → `flutter run`

## Yayınlama

### Google Play (Android)

```bash
# 1. İmzalama anahtarı üret (bir kez — bu dosyayı ASLA kaybetme, git'e koyma!)
keytool -genkey -v -keystore %USERPROFILE%\glowdeep-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias glowdeep

# 2. android/key.properties dosyası oluştur:
#    storePassword=ŞIFREN
#    keyPassword=ŞIFREN
#    keyAlias=glowdeep
#    storeFile=C:/Users/tolga/glowdeep-key.jks

# 3. android/app/build.gradle.kts içine signingConfig ekle (Flutter docs: "Signing the app")

# 4. Play Store'a AAB üret:
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

Sonra: [Google Play Console](https://play.google.com/console) → hesap ($25 tek seferlik) →
uygulama oluştur → AAB yükle → mağaza sayfası (açıklama, ekran görüntüleri, ikon) → yayınla.

### App Store (iOS)

iOS build **Mac gerektirir** (Xcode). Mac'in varsa:

```bash
flutter build ios --release
# sonra Xcode → Product → Archive → App Store Connect'e yükle
```

App Store geliştirici hesabı $99/yıl. Mac yoksa GitHub Actions + macOS runner veya
Codemagic gibi CI servisleriyle de derlenebilir.

## APK'yı telefona kurmak (mağazasız)

```bash
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```
Bu dosyayı telefona at → aç → "bilinmeyen kaynaklar"a izin ver → kur.

## Yol Haritası Fikirleri (v2)

- Çoklu oyunculu / haftalık liderlik tablosu (Firebase veya Supabase)
- Reklam entegrasyonu (AdMob rewarded revive — `google_mobile_ads`)
- Günlük "tohum" — herkese aynı harita, günlük rekabet
- Boss bölümleri, yeni tehlike tipleri (düşen stalaktit, ışık avcısı)
