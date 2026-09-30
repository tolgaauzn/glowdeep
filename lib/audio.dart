import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Prosedürel ses motoru — hiçbir ses dosyası yok; tüm efektler
/// çalışma zamanında WAV olarak sentezlenir (APK boyutunu şişirmez).
class Sfx {
  static final Sfx I = Sfx._();
  Sfx._();

  static const sr = 22050; // örnekleme hızı
  bool muted = false;
  bool _ready = false;

  final _pools = <String, List<AudioPlayer>>{};
  final _cursor = <String, int>{};
  final _wavs = <String, Uint8List>{};
  AudioPlayer? _ambient;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    for (final name in ['pickup', 'nearmiss', 'hit', 'shield', 'ui', 'chapter', 'buy', 'pulse', 'break']) {
      final n = name == 'pickup' ? 4 : 2;
      _pools[name] = List.generate(n, (_) {
        final p = AudioPlayer();
        p.setReleaseMode(ReleaseMode.stop);
        return p;
      });
      _cursor[name] = 0;
    }
  }

  // ------------------------------------------------------------------ WAV
  static Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void str(int off, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(off + i, s.codeUnitAt(i));
      }
    }
    str(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    str(8, 'WAVE'); str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);          // PCM
    data.setUint16(22, 1, Endian.little);          // mono
    data.setUint32(24, sr, Endian.little);
    data.setUint32(28, sr * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (var i = 0; i < n; i++) {
      data.setInt16(44 + i * 2, (samples[i].clamp(-1, 1) * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  static List<double> _tone({
    required double dur,
    required double Function(double t) freq,
    double vol = .5,
    double harmonic = 0,
  }) {
    final n = (dur * sr).round();
    final out = List<double>.filled(n, 0);
    double phase = 0;
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      phase += 2 * pi * freq(t) / sr;
      final env = exp(-t * (3.0 / dur));
      out[i] = (sin(phase) + harmonic * sin(phase * 2)) * env * vol;
    }
    return out;
  }

  static List<double> _noise(double dur, double vol, {double sweep = 0}) {
    final n = (dur * sr).round();
    final out = List<double>.filled(n, 0);
    final r = Random(7);
    double lp = 0;
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      lp += (r.nextDouble() * 2 - 1 - lp) * (0.25 + sweep * t);
      out[i] = lp * exp(-t * (4 / dur)) * vol;
    }
    return out;
  }

  Uint8List _get(String name) {
    return _wavs.putIfAbsent(name, () {
      switch (name) {
        case 'pickup':
          return _wav(_tone(dur: .10, vol: .45, harmonic: .3,
              freq: (t) => 760 + 900 * t / .10));
        case 'nearmiss':
          return _wav(_tone(dur: .07, vol: .4,
              freq: (t) => 1500 + 400 * t));
        case 'hit':
          final a = _noise(.35, .8);
          final b = _tone(dur: .4, vol: .5, freq: (t) => 220 * exp(-t * 6));
          for (var i = 0; i < a.length && i < b.length; i++) {
            a[i] += b[i];
          }
          return _wav(a);
        case 'shield':
          return _wav(_tone(dur: .18, vol: .5, harmonic: .6,
              freq: (t) => 620 - 150 * t));
        case 'ui':
          return _wav(_tone(dur: .05, vol: .35, freq: (_) => 620));
        case 'buy':
          final a = _tone(dur: .09, vol: .4, freq: (_) => 660);
          final b = _tone(dur: .12, vol: .4, freq: (_) => 990);
          final n = a.length + b.length;
          final out = List<double>.filled(n, 0);
          out.setRange(0, a.length, a);
          out.setRange(a.length, n, b);
          return _wav(out);
        case 'pulse':
          // genişleyen şok dalgası — düşen parlak ton + süpürmeli hışırtı
          final a = _tone(dur: .32, vol: .5, harmonic: .4,
              freq: (t) => 1400 * exp(-t * 7));
          final b = _noise(.3, .25, sweep: .6);
          final n = max(a.length, b.length);
          final out = List<double>.filled(n, 0);
          for (var i = 0; i < a.length; i++) {
            out[i] += a[i];
          }
          for (var i = 0; i < b.length; i++) {
            out[i] += b[i];
          }
          return _wav(out);
        case 'break':
          // kapı kırılması — kalın gürültü + düşük çınlama
          final a = _noise(.4, .7);
          final b = _tone(dur: .45, vol: .45, freq: (t) => 330 * exp(-t * 3));
          final n = max(a.length, b.length);
          final out = List<double>.filled(n, 0);
          for (var i = 0; i < a.length; i++) {
            out[i] += a[i];
          }
          for (var i = 0; i < b.length; i++) {
            out[i] += b[i];
          }
          return _wav(out);
        case 'chapter':
          final notes = [523.0, 659.0, 784.0, 1047.0];
          final seg = (.16 * sr).round();
          final out = List<double>.filled(seg * notes.length, 0);
          for (var k = 0; k < notes.length; k++) {
            final t = _tone(dur: .2, vol: .35, harmonic: .25, freq: (_) => notes[k]);
            for (var i = 0; i < t.length && k * seg + i < out.length; i++) {
              out[k * seg + i] += t[i];
            }
          }
          return _wav(out);
        default:
          return _wav(_tone(dur: .05, vol: .3, freq: (_) => 440));
      }
    });
  }

  void play(String name) {
    if (muted || !_ready) return;
    final pool = _pools[name];
    if (pool == null) return;
    final i = _cursor[name]! % pool.length;
    _cursor[name] = i + 1;
    pool[i].play(BytesSource(_get(name)));
  }

  void pickup(int combo) {
    if (muted || !_ready) return;
    // kombo yükseldikçe perde yükselir — çeşitlilik için yeniden sentezle
    final key = 'pickup';
    final pool = _pools[key]!;
    final i = _cursor[key]! % pool.length;
    _cursor[key] = i + 1;
    final w = _wav(_tone(
        dur: .09, vol: .4, harmonic: .3,
        freq: (t) => (700 + 70 * combo) + 800 * t));
    pool[i].play(BytesSource(w));
  }

  // ------------------------------------------------------------------ MÜZIK
  AudioPlayer? _melody;
  bool _melodyOn = false;
  bool _ambientOn = false;

  /// Menüde çalan yumuşak pentatonik döngü (~12.8sn)
  Future<void> startMelody() async {
    _melodyOn = true;
    if (muted || !_ready) return;
    const step = .8;
    const seq = <double>[
      220.0, 0, 261.63, 0, 329.63, 0, 392.0, 0,
      440.0, 0, 392.0, 0, 329.63, 0, 293.66, 0,
    ];
    final w = _wavs.putIfAbsent('melody', () {
      final n = (step * seq.length * sr).round();
      final out = List<double>.filled(n, 0);
      void note(double f, int at, double dur, double vol) {
        final t = _tone(dur: dur, vol: vol, harmonic: .35, freq: (_) => f);
        for (var i = 0; i < t.length && at + i < n; i++) {
          out[at + i] += t[i];
        }
      }
      for (var i = 0; i < seq.length; i++) {
        if (seq[i] > 0) note(seq[i], (i * step * sr).round(), .7, .16);
      }
      // yumuşak bas pad
      note(110.0, 0, 2.5, .10);
      note(130.81, (8 * step * sr).round(), 2.5, .10);
      return _wav(out);
    });
    _melody ??= AudioPlayer()
      ..setReleaseMode(ReleaseMode.loop)
      ..setVolume(.5);
    _melody!.play(BytesSource(w));
  }

  void stopMelody() {
    _melodyOn = false;
    _melody?.stop();
  }

  /// Mute değişiminde çalan müzikleri duraklat/devam ettir
  void applyMute() {
    if (muted) {
      _ambient?.pause();
      _melody?.pause();
    } else {
      if (_ambientOn) _ambient?.resume();
      if (_melodyOn) _melody?.resume();
    }
  }

  Future<void> startAmbient() async {
    _ambientOn = true;
    if (muted) return;
    // 4 saniyelik yumuşak drone — döngülenir
    final n = (4.0 * sr).round();
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      out[i] = (sin(2 * pi * 110 * t) * .5 +
              sin(2 * pi * 110.7 * t) * .3 +
              sin(2 * pi * 165 * t + sin(2 * pi * .13 * t)) * .2) *
          .12 *
          (0.7 + 0.3 * sin(2 * pi * .1 * t));
    }
    _ambient ??= AudioPlayer()
      ..setReleaseMode(ReleaseMode.loop)
      ..setVolume(.5);
    _ambient!.play(BytesSource(_wav(out)));
  }

  void stopAmbient() {
    _ambientOn = false;
    _ambient?.stop();
  }
}
