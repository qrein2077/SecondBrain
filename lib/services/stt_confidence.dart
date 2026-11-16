import '../models/stt_transcript.dart';

/// Heuristic confidence when whisper_ggml provides no token probs.
///
/// Uses word timestamps (when available) + text cues:
/// - duration vs character length (too fast / too slow)
/// - replacement char U+FFFD / odd punctuation-only tokens
/// - immediate word repeats (common hallucination)
/// - very short or empty-looking tokens
class SttConfidenceHeuristics {
  static const lowThreshold = 0.55;

  static SttTranscript fromSegments({
    required String fullText,
    required List<({String text, int fromMs, int toMs})> segments,
  }) {
    if (segments.isEmpty) {
      return fromPlainText(fullText);
    }

    final words = <SttWord>[];
    String? prevNorm;
    for (final s in segments) {
      final raw = s.text.trim();
      if (raw.isEmpty) continue;
      final durMs = (s.toMs - s.fromMs).clamp(0, 60000);
      final conf = scoreWord(
        text: raw,
        durationMs: durMs,
        prevNormalized: prevNorm,
      );
      words.add(
        SttWord(
          text: raw,
          confidence: conf,
          fromMs: s.fromMs,
          toMs: s.toMs,
        ),
      );
      prevNorm = _norm(raw);
    }

    final joined = words.map((w) => w.text).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return SttTranscript(
      text: joined.isNotEmpty ? joined : fullText.trim(),
      words: words,
      usedHeuristics: true,
    );
  }

  /// Fallback when no segments — mark whole phrase medium, flag weird tokens.
  static SttTranscript fromPlainText(String text) {
    final t = text.trim();
    if (t.isEmpty) {
      return const SttTranscript(text: '', words: [], usedHeuristics: true);
    }
    final parts = t.split(RegExp(r'\s+'));
    String? prev;
    final words = <SttWord>[];
    for (final p in parts) {
      final conf = scoreWord(text: p, durationMs: 0, prevNormalized: prev);
      words.add(SttWord(text: p, confidence: conf));
      prev = _norm(p);
    }
    return SttTranscript(text: t, words: words, usedHeuristics: true);
  }

  static double scoreWord({
    required String text,
    required int durationMs,
    String? prevNormalized,
  }) {
    var score = 0.82;
    final cleaned = text.trim();
    final letters = cleaned.replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');
    final norm = _norm(cleaned);

    if (cleaned.contains('\uFFFD')) {
      score -= 0.45;
    }
    if (letters.isEmpty) {
      score -= 0.35;
    }
    if (letters.length == 1 && durationMs > 600) {
      score -= 0.25;
    }
    if (prevNormalized != null &&
        prevNormalized.isNotEmpty &&
        prevNormalized == norm &&
        letters.length >= 2) {
      score -= 0.30; // repeated hallucination
    }

    if (durationMs > 0 && letters.isNotEmpty) {
      final msPerChar = durationMs / letters.length;
      // Spoken RU ~40–120 ms/char roughly; extremes look dubious.
      if (msPerChar < 18) {
        score -= 0.28;
      } else if (msPerChar < 28) {
        score -= 0.12;
      } else if (msPerChar > 280) {
        score -= 0.30;
      } else if (msPerChar > 180) {
        score -= 0.15;
      }
    }

    // Long run of same letter (аааа)
    if (RegExp(r'(.)\1{3,}').hasMatch(cleaned.toLowerCase())) {
      score -= 0.25;
    }

    return score.clamp(0.05, 0.98);
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');
}
