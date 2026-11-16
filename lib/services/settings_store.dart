import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Loads and persists [AppSettings] via SharedPreferences (Windows: AppData).
class SettingsStore extends ChangeNotifier {
  SettingsStore();

  static const _kVaultPath = 'vaultPath';
  static const _kOllamaBaseUrl = 'ollamaBaseUrl';
  static const _kModelName = 'modelName';
  static const _kSystemPrompt = 'systemPrompt';
  static const _kPromptVersion = 'systemPromptVersion';

  AppSettings _settings = const AppSettings();
  bool _loaded = false;

  AppSettings get settings => _settings;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    var prompt =
        prefs.getString(_kSystemPrompt) ?? AppSettings.defaultSystemPrompt;
    final storedVersion = prefs.getInt(_kPromptVersion) ?? 1;

    // Migrate shipped defaults to the latest multi-file vault-scoped prompt.
    // Custom user prompts are left untouched.
    if (storedVersion < AppSettings.currentPromptVersion &&
        AppSettings.isShippedDefaultPrompt(prompt)) {
      prompt = AppSettings.defaultSystemPrompt;
      await prefs.setString(_kSystemPrompt, prompt);
      await prefs.setInt(
        _kPromptVersion,
        AppSettings.currentPromptVersion,
      );
    } else if (storedVersion < AppSettings.currentPromptVersion) {
      // Custom prompt: bump version marker only so we don't re-prompt every launch.
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
      systemPrompt: prompt,
    );
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(AppSettings next) async {
    _settings = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVaultPath, next.vaultPath);
    await prefs.setString(_kOllamaBaseUrl, next.ollamaBaseUrl);
    await prefs.setString(_kModelName, next.modelName);
    await prefs.setString(_kSystemPrompt, next.systemPrompt);
    await prefs.setInt(_kPromptVersion, AppSettings.currentPromptVersion);
  }
}
