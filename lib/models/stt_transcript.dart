/// One word/segment from Whisper with heuristic confidence (0–1).
///
/// whisper_ggml does **not** expose token probabilities; [confidence] is
/// estimated from timing + text heuristics (see [SttConfidenceHeuristics]).
class SttWord {
  const SttWord({
    required this.text,
    required this.confidence,
    this.fromMs = 0,
    this.toMs = 0,
  });

  final String text;
  final double confidence;
  final int fromMs;
  final int toMs;

  bool get isLow => confidence < 0.55;
}

class SttTranscript {
  const SttTranscript({
    required this.text,
    this.words = const [],
    this.usedHeuristics = true,
  });

  final String text;
  final List<SttWord> words;

  /// Always true for whisper_ggml today (no native probs).
  final bool usedHeuristics;

  bool get hasLowConfidence => words.any((w) => w.isLow);

  int get lowCount => words.where((w) => w.isLow).length;
}
