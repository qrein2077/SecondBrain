import 'package:material_ui/material_ui.dart';

import '../models/stt_transcript.dart';

/// Review strip above chat input: yellow underline = low heuristic confidence.
class SttReviewStrip extends StatelessWidget {
  const SttReviewStrip({
    super.key,
    required this.transcript,
    required this.onAccept,
    required this.onDiscard,
  });

  final SttTranscript transcript;
  final VoidCallback onAccept;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.bodyMedium;
    final lowStyle = base?.copyWith(
      backgroundColor: const Color(0xFFFFF59D),
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFFF9A825),
      decorationThickness: 2,
    );

    final spans = <InlineSpan>[];
    for (var i = 0; i < transcript.words.length; i++) {
      if (i > 0) spans.add(TextSpan(text: ' ', style: base));
      final w = transcript.words[i];
      spans.add(
        TextSpan(
          text: w.text,
          style: w.isLow ? lowStyle : base,
        ),
      );
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: transcript.text, style: base));
    }

    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.hearing, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    transcript.hasLowConfidence
                        ? 'Проверьте жёлтые слова (низкая уверенность, эвристика)'
                        : 'Расшифровка Whisper — можно править в поле ниже',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                TextButton(
                  onPressed: onDiscard,
                  child: const Text('Сброс'),
                ),
                FilledButton.tonal(
                  onPressed: onAccept,
                  child: const Text('В поле'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text.rich(TextSpan(children: spans)),
            if (transcript.usedHeuristics)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'whisper_ggml не отдаёт token probs — подсветка по длительности '
                  'слов и текстовым эвристикам; не калиброванная confidence.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
