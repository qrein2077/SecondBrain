import 'dart:convert';

import '../models/chat_message.dart';

/// Parses assistant replies for optional PROPOSE_NOTES draft blocks.
class AgentParser {
  static final _blockRe = RegExp(
    r'<<<PROPOSE_NOTES>>>\s*([\s\S]*?)\s*<<<END_PROPOSE_NOTES>>>',
    multiLine: true,
  );

  /// Returns display text (block stripped) and optional draft bundle.
  static ParsedAgentReply parse(String raw) {
    final match = _blockRe.firstMatch(raw);
    if (match == null) {
      return ParsedAgentReply(displayText: raw.trim(), draft: null);
    }

    final jsonPart = match.group(1)!.trim();
    NoteDraftBundle? draft;
    try {
      final decoded = jsonDecode(jsonPart);
      final list = decoded is List
          ? decoded
          : (decoded is Map && decoded['files'] is List)
              ? decoded['files'] as List
              : null;
      if (list != null) {
        final files = <NoteDraft>[];
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            files.add(NoteDraft.fromJson(item));
          } else if (item is Map) {
            files.add(NoteDraft.fromJson(Map<String, dynamic>.from(item)));
          }
        }
        files.removeWhere((f) => f.path.isEmpty);
        if (files.isNotEmpty) {
          draft = NoteDraftBundle(files: files);
        }
      }
    } catch (_) {
      // Keep raw text; surface parse error in display.
      final without = raw.replaceFirst(_blockRe, '').trim();
      return ParsedAgentReply(
        displayText: '$without\n\n⚠️ Не удалось разобрать блок PROPOSE_NOTES.',
        draft: null,
      );
    }

    final display = raw.replaceFirst(_blockRe, '').trim();
    return ParsedAgentReply(
      displayText: display.isEmpty
          ? 'Предложены черновики заметок (${draft?.files.length ?? 0}).'
          : display,
      draft: draft,
    );
  }
}

class ParsedAgentReply {
  const ParsedAgentReply({required this.displayText, required this.draft});

  final String displayText;
  final NoteDraftBundle? draft;
}
