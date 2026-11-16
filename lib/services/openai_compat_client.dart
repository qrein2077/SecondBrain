import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

/// OpenAI-compatible chat completions client.
/// Used for local Ollama (`…/v1/chat/completions`) and Gemini AI Studio
/// (`…/v1beta/openai/chat/completions`). Concurrency = 1.
class OpenAiCompatClient {
  OpenAiCompatClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const geminiOpenAiBase =
      'https://generativelanguage.googleapis.com/v1beta/openai';

  final http.Client _http;
  Future<void> _queue = Future.value();

  Future<String> chat({
    required Uri completionsUri,
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
    String? bearerApiKey,
    Map<String, dynamic>? extraBody,
  }) {
    final completer = Completer<String>();
    _queue = _queue.then((_) async {
      try {
        final result = await _chatUnlocked(
          completionsUri: completionsUri,
          model: model,
          systemPrompt: systemPrompt,
          history: history,
          bearerApiKey: bearerApiKey,
          extraBody: extraBody,
        );
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<String> chatOllama({
    required String baseUrl,
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) {
    final root = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    return chat(
      completionsUri: Uri.parse('$root/v1/chat/completions'),
      model: model,
      systemPrompt: systemPrompt,
      history: history,
      extraBody: const {
        'options': {'num_predict': 2048},
      },
    );
  }

  Future<String> chatGemini({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) {
    return chat(
      completionsUri: Uri.parse('$geminiOpenAiBase/chat/completions'),
      model: model,
      systemPrompt: systemPrompt,
      history: history,
      bearerApiKey: apiKey,
    );
  }

  Future<String> _chatUnlocked({
    required Uri completionsUri,
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
    String? bearerApiKey,
    Map<String, dynamic>? extraBody,
  }) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      for (final m in history)
        if (m.role == ChatRole.user || m.role == ChatRole.assistant)
          {
            'role': m.role == ChatRole.user ? 'user' : 'assistant',
            'content': m.content,
          },
    ];

    final bodyMap = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': false,
      ...?extraBody,
    };

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (bearerApiKey != null && bearerApiKey.isNotEmpty)
        'Authorization': 'Bearer $bearerApiKey',
    };

    final response = await _http
        .post(
          completionsUri,
          headers: headers,
          body: jsonEncode(bodyMap),
        )
        .timeout(const Duration(minutes: 5));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmException(
        'LLM HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw LlmException('Пустой ответ LLM');
    }
    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = message?['content'];
    if (content is! String) {
      throw LlmException('Нет content в ответе LLM');
    }
    return content;
  }

  Future<bool> pingOllama(String baseUrl) async {
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

  /// Light check: list models via OpenAI-compat (needs API key).
  Future<bool> pingGemini(String apiKey) async {
    if (apiKey.trim().isEmpty) return false;
    try {
      final uri = Uri.parse('$geminiOpenAiBase/models');
      final response = await _http
          .get(
            uri,
            headers: {'Authorization': 'Bearer ${apiKey.trim()}'},
          )
          .timeout(const Duration(seconds: 8));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _http.close();
  }
}

class LlmException implements Exception {
  LlmException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// @Deprecated — use [LlmException].
typedef OllamaException = LlmException;
