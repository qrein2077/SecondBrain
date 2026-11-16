import 'cloud_provider.dart';
import 'llm_mode.dart';

/// Persistent app settings for SecondBrain MVP.
/// API keys are NOT stored here — see secure storage in [SettingsStore].
class AppSettings {
  const AppSettings({
    this.vaultPath = '',
    this.ollamaBaseUrl = 'http://127.0.0.1:11434',
    this.modelName = 'qwen2.5:7b',
    this.geminiModel = AppSettings.defaultGeminiModel,
    this.groqModel = AppSettings.defaultGroqModel,
    this.openRouterModel = AppSettings.defaultOpenRouterModel,
    this.llmMode = LlmMode.local,
    this.cloudProvider = CloudProvider.groq,
    this.systemPrompt = AppSettings.defaultSystemPrompt,
  });

  final String vaultPath;
  final String ollamaBaseUrl;

  /// Local Ollama model tag (default Qwen2.5).
  final String modelName;

  final String geminiModel;
  final String groqModel;
  final String openRouterModel;

  /// local | cloud | auto — default local (Ollama).
  final LlmMode llmMode;

  /// Which cloud backend when mode is cloud or auto-fallback.
  /// Default Groq — often reachable where Gemini AI Studio is region-blocked.
  final CloudProvider cloudProvider;

  final String systemPrompt;

  static const defaultGeminiModel = 'gemini-2.5-flash';
  static const defaultGroqModel = 'llama-3.1-8b-instant';
  static const defaultOpenRouterModel =
      'meta-llama/llama-3.1-8b-instruct:free';

  /// Bumped when default agent instructions change meaningfully.
  static const int currentPromptVersion = 2;

  /// Previous shipped default — used to migrate AppData without wiping custom prompts.
  static const legacyDefaultSystemPromptV1 = '''
Ты — универсальный AI-компаньон SecondBrain для Obsidian vault пользователя.
Отвечай по-русски, если пользователь пишет по-русски.
Помогай структурировать идеи, отвечать по заметкам и предлагать правки.

ВАЖНО про запись в vault:
- Ты НИКОГДА не пишешь файлы сам. Ты только ПРЕДЛАГАЕШЬ черновики.
- Когда нужно создать или обновить одну или несколько заметок .md, добавь в конец ответа блок:

<<<PROPOSE_NOTES>>>
[
  {"path": "относительный/путь.md", "op": "create", "content": "# Заголовок\\n\\nТекст с [[wiki-links]]"},
  {"path": "другая.md", "op": "update", "content": "полное новое содержимое файла"}
]
<<<END_PROPOSE_NOTES>>>

Правила:
- path только относительно корня vault, без .. и абсолютных путей.
- op: "create" или "update".
- Связывай новые заметки через [[wiki-links]].
- Можно предложить несколько связанных файлов.
- Обычный текст ответа пиши ДО блока PROPOSE_NOTES.
- Если запись в vault не нужна — не добавляй блок.
''';

  static const defaultSystemPrompt = '''
Ты — универсальный AI-компаньон SecondBrain для Obsidian vault пользователя.
Отвечай по-русски, если пользователь пишет по-русски.
Помогай структурировать идеи, отвечать по заметкам и предлагать правки.

ОБЛАСТЬ РАБОТЫ — ВЕСЬ VAULT:
- Ты НЕ привязан к одной открытой заметке в редакторе.
- Открытый файл (если указан в контексте) — только справка; цель — весь vault.
- Идеи и задачи по умолчанию раскладывай на НЕСКОЛЬКО связанных .md с [[wiki-links]], а не в один файл.
- Можно create и update в одном черновике (пакет).
- Не ограничивайся Inbox: предлагай разумные пути/подпапки внутри vault.

ВАЖНО про запись:
- Ты НИКОГДА не пишешь файлы сам. Только ПРЕДЛАГАЕШЬ черновики.
- Когда нужно создать/обновить одну или несколько заметок, в КОНЕЦ ответа добавь блок:

<<<PROPOSE_NOTES>>>
[
  {"path": "Тема/обзор.md", "op": "create", "content": "# Обзор\\n\\nСм. [[детали]] и [[задачи]]"},
  {"path": "Тема/детали.md", "op": "create", "content": "# Детали\\n\\nНазад: [[обзор]]"},
  {"path": "Тема/задачи.md", "op": "create", "content": "# Задачи\\n\\n- [ ] …\\n\\n[[обзор]]"}
]
<<<END_PROPOSE_NOTES>>>

Правила блока:
- path только относительно корня vault, без .. и абсолютных путей.
- op: "create" (новый) или "update" (полная замена содержимого существующего).
- В одном блоке — весь пакет файлов этого предложения (1…N).
- Связывай заметки через [[wiki-links]] друг на друга и на уже существующие пути из контекста vault.
- Обычный текст ответа — ДО блока. Без блока, если запись в vault не нужна.
- Не предлагай удаление файлов.
''';

  /// True if [prompt] is a known shipped default (safe to auto-migrate).
  static bool isShippedDefaultPrompt(String prompt) {
    final t = prompt.trim();
    return t.isEmpty ||
        t == defaultSystemPrompt.trim() ||
        t == legacyDefaultSystemPromptV1.trim();
  }

  String cloudModelFor(CloudProvider provider) {
    switch (provider) {
      case CloudProvider.gemini:
        return geminiModel;
      case CloudProvider.groq:
        return groqModel;
      case CloudProvider.openRouter:
        return openRouterModel;
    }
  }

  AppSettings copyWith({
    String? vaultPath,
    String? ollamaBaseUrl,
    String? modelName,
    String? geminiModel,
    String? groqModel,
    String? openRouterModel,
    LlmMode? llmMode,
    CloudProvider? cloudProvider,
    String? systemPrompt,
  }) {
    return AppSettings(
      vaultPath: vaultPath ?? this.vaultPath,
      ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
      modelName: modelName ?? this.modelName,
      geminiModel: geminiModel ?? this.geminiModel,
      groqModel: groqModel ?? this.groqModel,
      openRouterModel: openRouterModel ?? this.openRouterModel,
      llmMode: llmMode ?? this.llmMode,
      cloudProvider: cloudProvider ?? this.cloudProvider,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    );
  }
}
