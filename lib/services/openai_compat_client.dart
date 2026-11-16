import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/cloud_provider.dart';

/// OpenAI-compatible chat completions client (Ollama + cloud providers).
/// Concurrency = 1.
class OpenAiCompatClient {
  OpenAiCompatClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const geminiOpenAiBase =
      'https://generativelanguage.googleapis.com/v1beta/openai';
  static const groqOpenAiBase = 'https://api.groq.com/openai/v1';
  static const openRouterOpenAiBase = 'https://openrouter.ai/api/v1';

  final http.Client _http;
  Future<void> _queue = Future.value();

  Future<String> chat({
    required Uri completionsUri,
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
    String? bearerApiKey,
    Map<String, String>? extraHeaders,
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
          extraHeaders: extraHeaders,
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

  Future<String> chatCloud({
    required CloudProvider provider,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) {
    switch (provider) {
      case CloudProvider.gemini:
        return chatGemini(
          apiKey: apiKey,
          model: model,
          systemPrompt: systemPrompt,
          history: history,
        );
      case CloudProvider.groq:
        return chatGroq(
          apiKey: apiKey,
          model: model,
          systemPrompt: systemPrompt,
          history: history,
        );
      case CloudProvider.openRouter:
        return chatOpenRouter(
          apiKey: apiKey,
          model: model,
          systemPrompt: systemPrompt,
          history: history,
        );
    }
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

  Future<String> chatGroq({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) {
    return chat(
      completionsUri: Uri.parse('$groqOpenAiBase/chat/completions'),
      model: model,
      systemPrompt: systemPrompt,
      history: history,
      bearerApiKey: apiKey,
    );
  }

  Future<String> chatOpenRouter({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) {
    return chat(
      completionsUri: Uri.parse('$openRouterOpenAiBase/chat/completions'),
      model: model,
      systemPrompt: systemPrompt,
      history: history,
      bearerApiKey: apiKey,
      extraHeaders: const {
        // Recommended by OpenRouter for rankings / app identity.
        'HTTP-Referer': 'https://github.com/qrein2077/SecondBrain',
        'X-Title': 'SecondBrain',
      },
    );
  }

  Future<String> _chatUnlocked({
    required Uri completionsUri,
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
    String? bearerApiKey,
    Map<String, String>? extraHeaders,
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
      ...?extraHeaders,
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

  Future<bool> pingCloud(CloudProvider provider, String apiKey) async {
    if (apiKey.trim().isEmpty) return false;
    try {
      final Uri uri;
      switch (provider) {
        case CloudProvider.gemini:
          uri = Uri.parse('$geminiOpenAiBase/models');
        case CloudProvider.groq:
          uri = Uri.parse('$groqOpenAiBase/models');
        case CloudProvider.openRouter:
          uri = Uri.parse('$openRouterOpenAiBase/models');
      }
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

  /// @Deprecated — use [pingCloud].
  Future<bool> pingGemini(String apiKey) =>
      pingCloud(CloudProvider.gemini, apiKey);

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

typedef OllamaException = LlmException;
