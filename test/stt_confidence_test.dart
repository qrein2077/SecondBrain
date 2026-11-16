import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/services/stt_confidence.dart';
import 'package:secondbrain/services/wav_silence_trim.dart';
import 'dart:typed_data';

void main() {
  test('marks repeated hallucinated words low', () {
    final t = SttConfidenceHeuristics.fromSegments(
      fullText: 'физика физика физика',
      segments: const [
        (text: 'физика', fromMs: 0, toMs: 400),
        (text: 'физика', fromMs: 400, toMs: 800),
        (text: 'физика', fromMs: 800, toMs: 1200),
      ],
    );
    expect(t.words.length, 3);
    expect(t.words[0].isLow, isFalse);
    expect(t.words[1].isLow, isTrue);
    expect(t.usedHeuristics, isTrue);
  });

  test('marks replacement char low', () {
    final conf = SttConfidenceHeuristics.scoreWord(
      text: 'физ\uFFFDка',
      durationMs: 300,
      prevNormalized: null,
    );
    expect(conf < SttConfidenceHeuristics.lowThreshold, isTrue);
  });

  test('WavSilenceTrim no-op on tiny buffer', () {
    expect(WavSilenceTrim.trimBytes(Uint8List(10)), isNull);
  });

  test('WavSilenceTrim trims silent PCM16 mono', () {
    // Minimal WAV: 44-byte header + silence + beep + silence
    final sampleRate = 16000;
    final channels = 1;
    final silence = List<int>.filled(800, 0); // 400 samples * 2 bytes
    final tone = <int>[];
    for (var i = 0; i < 200; i++) {
      const amp = 8000;
      tone.add(amp & 0xff);
      tone.add((amp >> 8) & 0xff);
    }
    final pcm = [...silence, ...tone, ...silence];
    final dataSize = pcm.length;
    final bytes = BytesBuilder();
    void u32(int v) {
      bytes.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
    }

    void u16(int v) {
      bytes.add([v & 0xff, (v >> 8) & 0xff]);
    }

    bytes.add('RIFF'.codeUnits);
    u32(36 + dataSize);
    bytes.add('WAVE'.codeUnits);
    bytes.add('fmt '.codeUnits);
    u32(16);
    u16(1); // PCM
    u16(channels);
    u32(sampleRate);
    u32(sampleRate * channels * 2);
    u16(channels * 2);
    u16(16);
    bytes.add('data'.codeUnits);
    u32(dataSize);
    bytes.add(pcm);

    final raw = Uint8List.fromList(bytes.toBytes());
    final trimmed = WavSilenceTrim.trimBytes(raw, threshold: 500, padMs: 0);
    expect(trimmed, isNotNull);
    expect(trimmed!.length, lessThan(raw.length));
  });
}
