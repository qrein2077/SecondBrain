import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

/// OpenAI-compatible chat client for local Ollama.
/// Enforces concurrency = 1 so the PC stays lightly loaded.
class OllamaClient {
  OllamaClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;
  Future<void> _queue = Future.value();

  /// Serializes chat calls (one active generation at a time).
  Future<String> chat({
    required String baseUrl,
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) {
    final completer = Completer<String>();
    _queue = _queue.then((_) async {
      try {
        final result = await _chatUnlocked(
          baseUrl: baseUrl,
          model: model,
          systemPrompt: systemPrompt,
          history: history,
        );
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<String> _chatUnlocked({
    required String baseUrl,
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) async {
    final root = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$root/v1/chat/completions');

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      for (final m in history)
        if (m.role == ChatRole.user || m.role == ChatRole.assistant)
          {
            'role': m.role == ChatRole.user ? 'user' : 'assistant',
            'content': m.content,
          },
    ];

    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'stream': false,
      // Keep load light; Ollama may ignore some fields.
      'options': {
        'num_predict': 2048,
      },
    });

    final response = await _http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            // No cloud API key — local Ollama only.
          },
          body: body,
        )
        .timeout(const Duration(minutes: 5));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OllamaException(
        'Ollama HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw OllamaException('Пустой ответ от Ollama');
    }
    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null) {
      throw OllamaException('Нет content в ответе Ollama');
    }
    return content;
  }

  Future<bool> ping(String baseUrl) async {
    try {
      final root = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
      final uri = Uri.parse('$root/api/tags');
      final response =
          await _http.get(uri).timeout(const Duration(seconds: 3));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _http.close();
  }
}

class OllamaException implements Exception {
  OllamaException(this.message);
  final String message;

  @override
  String toString() => message;
}
