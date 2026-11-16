import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/llm_mode.dart';

/// Loads/persists [AppSettings]. Gemini API key lives in secure storage only.
class SettingsStore extends ChangeNotifier {
  SettingsStore({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ?? const FlutterSecureStorage();

  static const _kVaultPath = 'vaultPath';
  static const _kOllamaBaseUrl = 'ollamaBaseUrl';
  static const _kModelName = 'modelName';
  static const _kGeminiModel = 'geminiModel';
  static const _kLlmMode = 'llmMode';
  static const _kSystemPrompt = 'systemPrompt';
  static const _kPromptVersion = 'systemPromptVersion';
  static const _kGeminiApiKey = 'gemini_api_key';

  final FlutterSecureStorage _secure;

  AppSettings _settings = const AppSettings();
  String? _geminiApiKey;
  bool _loaded = false;

  AppSettings get settings => _settings;
  bool get isLoaded => _loaded;
  bool get hasGeminiApiKey =>
      _geminiApiKey != null && _geminiApiKey!.trim().isNotEmpty;

  /// In-memory key for chat; never logged. Empty if unset.
  String get geminiApiKey => _geminiApiKey?.trim() ?? '';

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

    _settings = AppSettings(
      vaultPath: prefs.getString(_kVaultPath) ?? '',
      ollamaBaseUrl:
          prefs.getString(_kOllamaBaseUrl) ?? 'http://127.0.0.1:11434',
      modelName: prefs.getString(_kModelName) ?? 'qwen2.5:7b',
      geminiModel:
          prefs.getString(_kGeminiModel) ?? AppSettings.defaultGeminiModel,
      llmMode: LlmModeX.fromStorage(prefs.getString(_kLlmMode)),
      systemPrompt: prompt,
    );

    try {
      _geminiApiKey = await _secure.read(key: _kGeminiApiKey);
    } catch (_) {
      _geminiApiKey = null;
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> update(
    AppSettings next, {
    String? geminiApiKey,
    bool clearGeminiApiKey = false,
  }) async {
    _settings = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVaultPath, next.vaultPath);
    await prefs.setString(_kOllamaBaseUrl, next.ollamaBaseUrl);
    await prefs.setString(_kModelName, next.modelName);
    await prefs.setString(_kGeminiModel, next.geminiModel);
    await prefs.setString(_kLlmMode, next.llmMode.storageValue);
    await prefs.setString(_kSystemPrompt, next.systemPrompt);
    await prefs.setInt(_kPromptVersion, AppSettings.currentPromptVersion);

    if (clearGeminiApiKey) {
      await _secure.delete(key: _kGeminiApiKey);
      _geminiApiKey = null;
    } else if (geminiApiKey != null) {
      final trimmed = geminiApiKey.trim();
      if (trimmed.isEmpty) {
        await _secure.delete(key: _kGeminiApiKey);
        _geminiApiKey = null;
      } else {
        await _secure.write(key: _kGeminiApiKey, value: trimmed);
        _geminiApiKey = trimmed;
      }
    }
    notifyListeners();
  }
}
