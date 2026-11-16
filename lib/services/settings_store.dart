import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/cloud_provider.dart';
import '../models/llm_mode.dart';

/// Loads/persists [AppSettings]. Cloud API keys live in secure storage only.
class SettingsStore extends ChangeNotifier {
  SettingsStore({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ?? const FlutterSecureStorage();

  static const _kVaultPath = 'vaultPath';
  static const _kOllamaBaseUrl = 'ollamaBaseUrl';
  static const _kModelName = 'modelName';
  static const _kGeminiModel = 'geminiModel';
  static const _kGroqModel = 'groqModel';
  static const _kOpenRouterModel = 'openRouterModel';
  static const _kLlmMode = 'llmMode';
  static const _kCloudProvider = 'cloudProvider';
  static const _kSystemPrompt = 'systemPrompt';
  static const _kPromptVersion = 'systemPromptVersion';

  static const _kGeminiApiKey = 'gemini_api_key';
  static const _kGroqApiKey = 'groq_api_key';
  static const _kOpenRouterApiKey = 'openrouter_api_key';

  final FlutterSecureStorage _secure;

  AppSettings _settings = const AppSettings();
  String? _geminiApiKey;
  String? _groqApiKey;
  String? _openRouterApiKey;
  bool _loaded = false;

  AppSettings get settings => _settings;
  bool get isLoaded => _loaded;

  bool get hasGeminiApiKey => _nonEmpty(_geminiApiKey);
  bool get hasGroqApiKey => _nonEmpty(_groqApiKey);
  bool get hasOpenRouterApiKey => _nonEmpty(_openRouterApiKey);

  String get geminiApiKey => _geminiApiKey?.trim() ?? '';
  String get groqApiKey => _groqApiKey?.trim() ?? '';
  String get openRouterApiKey => _openRouterApiKey?.trim() ?? '';

  bool hasKeyFor(CloudProvider provider) {
    switch (provider) {
      case CloudProvider.gemini:
        return hasGeminiApiKey;
      case CloudProvider.groq:
        return hasGroqApiKey;
      case CloudProvider.openRouter:
        return hasOpenRouterApiKey;
    }
  }

  String apiKeyFor(CloudProvider provider) {
    switch (provider) {
      case CloudProvider.gemini:
        return geminiApiKey;
      case CloudProvider.groq:
        return groqApiKey;
      case CloudProvider.openRouter:
        return openRouterApiKey;
    }
  }

  static bool _nonEmpty(String? v) => v != null && v.trim().isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    var prompt =
        prefs.getString(_kSystemPrompt) ?? AppSettings.defaultSystemPrompt;
    final storedVersion = prefs.getInt(_kPromptVersion) ?? 1;

    if (storedVersion < AppSettings.currentPromptVersion &&
        AppSettings.isShippedDefaultPrompt(prompt)) {
      prompt = AppSettings.defaultSystemPrompt;
      await prefs.setString(_kSystemPrompt, prompt);
      await prefs.setInt(
        _kPromptVersion,
        AppSettings.currentPromptVersion,
      );
    } else if (storedVersion < AppSettings.currentPromptVersion) {
      await prefs.setInt(
        _kPromptVersion,
        AppSettings.currentPromptVersion,
      );
    }

    var geminiModel =
        prefs.getString(_kGeminiModel) ?? AppSettings.defaultGeminiModel;
    // Migrate retired AI Studio default for new users / stored old default only.
    if (geminiModel == AppSettings.legacyDefaultGeminiModel ||
        geminiModel == 'models/${AppSettings.legacyDefaultGeminiModel}') {
      geminiModel = AppSettings.defaultGeminiModel;
      await prefs.setString(_kGeminiModel, geminiModel);
    }

    var groqModel =
        prefs.getString(_kGroqModel) ?? AppSettings.defaultGroqModel;
    // Migrate retired free-tier Llama IDs (shutdown Aug 2026).
    if (AppSettings.legacyRetiredGroqModels.contains(groqModel)) {
      groqModel = AppSettings.defaultGroqModel;
      await prefs.setString(_kGroqModel, groqModel);
    }

    _settings = AppSettings(
      vaultPath: prefs.getString(_kVaultPath) ?? '',
      ollamaBaseUrl:
          prefs.getString(_kOllamaBaseUrl) ?? 'http://127.0.0.1:11434',
      modelName: prefs.getString(_kModelName) ?? 'qwen2.5:7b',
      geminiModel: geminiModel,
      groqModel: groqModel,
      openRouterModel: prefs.getString(_kOpenRouterModel) ??
          AppSettings.defaultOpenRouterModel,
      llmMode: LlmModeX.fromStorage(prefs.getString(_kLlmMode)),
      cloudProvider:
          CloudProviderX.fromStorage(prefs.getString(_kCloudProvider)),
      systemPrompt: prompt,
    );

    try {
      _geminiApiKey = await _secure.read(key: _kGeminiApiKey);
      _groqApiKey = await _secure.read(key: _kGroqApiKey);
      _openRouterApiKey = await _secure.read(key: _kOpenRouterApiKey);
    } catch (_) {
      // Leave keys null if secure storage fails.
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _writeKey(String storageKey, String? value) async {
    if (value == null) return;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _secure.delete(key: storageKey);
    } else {
      await _secure.write(key: storageKey, value: trimmed);
    }
  }

  Future<void> update(
    AppSettings next, {
    String? geminiApiKey,
    String? groqApiKey,
    String? openRouterApiKey,
    bool clearGeminiApiKey = false,
    bool clearGroqApiKey = false,
    bool clearOpenRouterApiKey = false,
  }) async {
    _settings = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVaultPath, next.vaultPath);
    await prefs.setString(_kOllamaBaseUrl, next.ollamaBaseUrl);
    await prefs.setString(_kModelName, next.modelName);
    await prefs.setString(_kGeminiModel, next.geminiModel);
    await prefs.setString(_kGroqModel, next.groqModel);
    await prefs.setString(_kOpenRouterModel, next.openRouterModel);
    await prefs.setString(_kLlmMode, next.llmMode.storageValue);
    await prefs.setString(_kCloudProvider, next.cloudProvider.storageValue);
    await prefs.setString(_kSystemPrompt, next.systemPrompt);
    await prefs.setInt(_kPromptVersion, AppSettings.currentPromptVersion);

    if (clearGeminiApiKey) {
      await _secure.delete(key: _kGeminiApiKey);
      _geminiApiKey = null;
    } else if (geminiApiKey != null) {
      await _writeKey(_kGeminiApiKey, geminiApiKey);
      _geminiApiKey = geminiApiKey.trim().isEmpty ? null : geminiApiKey.trim();
    }

    if (clearGroqApiKey) {
      await _secure.delete(key: _kGroqApiKey);
      _groqApiKey = null;
    } else if (groqApiKey != null) {
      await _writeKey(_kGroqApiKey, groqApiKey);
      _groqApiKey = groqApiKey.trim().isEmpty ? null : groqApiKey.trim();
    }

    if (clearOpenRouterApiKey) {
      await _secure.delete(key: _kOpenRouterApiKey);
      _openRouterApiKey = null;
    } else if (openRouterApiKey != null) {
      await _writeKey(_kOpenRouterApiKey, openRouterApiKey);
      _openRouterApiKey =
          openRouterApiKey.trim().isEmpty ? null : openRouterApiKey.trim();
    }

    notifyListeners();
  }
}
