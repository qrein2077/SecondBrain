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
    this.qaOnly = false,
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

  /// When true: answers only — no PROPOSE_NOTES / vault drafts.
  /// When false: may edit vault after clarifying questions + user Approve.
  final bool qaOnly;

  final String systemPrompt;

  /// OpenAI-compat model id (no `models/` prefix).
  static const defaultGeminiModel = 'gemini-3.8-flash';

  /// Previous shipped Gemini default — migrate AppData when still this value.
  static const legacyDefaultGeminiModel = 'gemini-2.5-flash';

  /// Free/developer-tier chat model (Llama 3.1/3.3 retired from free tier Aug 2026).
  static const defaultGroqModel = 'openai/gpt-oss-20b';

  /// Previous shipped Groq default — migrate AppData when still this value.
  static const legacyDefaultGroqModel = 'llama-3.1-8b-instant';

  /// Also retired from free/developer tier; migrate if still stored.
  static const legacyRetiredGroqModels = <String>[
    legacyDefaultGroqModel,
    'llama-3.3-70b-versatile',
  ];

  static const defaultOpenRouterModel =
      'meta-llama/llama-3.1-8b-instruct:free';

  /// Bumped when default agent instructions change meaningfully.
  static const int currentPromptVersion = 3;

  /// Appended at runtime when [qaOnly] is true (does not replace custom prompts).
  static const qaOnlyAddonPrompt = '''
РЕЖИМ «ТОЛЬКО ОТВЕТЫ» ВКЛЮЧЁН ПРИЛОЖЕНИЕМ:
- Отвечай на вопросы пользователя. Объясняй, советуй, резюмируй по материалам vault.
- Используй блок «Выдержки из vault» ниже как основной источник фактов.
- ЗАПРЕЩЕНО отправлять пользователя «открыть файл / посмотреть самому» — анализируй выдержки сам.
- Если выдержек нет или они не покрывают тему — честно скажи, что в vault этого не нашёл.
- ЗАПРЕЩЕНО предлагать создание или обновление заметок vault.
- НИКОГДА не выводи блок <<<PROPOSE_NOTES>>> … <<<END_PROPOSE_NOTES>>>.
- Не предлагай пути файлов как черновики на запись. Vault не меняется в этом режиме.
''';

  /// Always appended for grounded Q&A (both modes).
  static const vaultGroundingAddonPrompt = '''
ОТВЕТЫ ПО VAULT (обязательно):
- При вопросах о знаниях/заметках пользователя опирайся на «Выдержки из vault».
- Не проси пользователя открыть или прочитать файлы вручную.
- Если релевантных выдержек нет — прямо скажи об этом.
''';

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

  /// Shipped multi-file vault prompt (v2) before clarifying-questions update.
  static const legacyDefaultSystemPromptV2 = '''
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

УТОЧНЯЮЩИЕ ВОПРОСЫ (обязательно в режиме правок vault):
- Прежде чем предлагать заметки, ЧАСТО задавай 1–3 коротких уточняющих вопроса
  (цель, структура, куда класть файлы, уровень детализации, что уже есть в vault).
- НЕ выводи блок <<<PROPOSE_NOTES>>> в том же ответе, где ещё нужны уточнения.
- Предлагай черновики ТОЛЬКО после того, как пользователь подтвердил направление
  («да», «ок», «пиши», «предлагай», согласие с планом) или явно попросил сразу создать заметки.
- Если запрос уже очень конкретный и пользователь явно просит создать/обновить файлы — можно предложить пакет сразу.

ВАЖНО про запись:
- Ты НИКОГДА не пишешь файлы сам. Только ПРЕДЛАГАЕШЬ черновики.
- Когда нужно создать/обновить одну или несколько заметок (и направление подтверждено), в КОНЕЦ ответа добавь блок:

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
        t == legacyDefaultSystemPromptV1.trim() ||
        t == legacyDefaultSystemPromptV2.trim();
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
    bool? qaOnly,
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
      qaOnly: qaOnly ?? this.qaOnly,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    );
  }
}
