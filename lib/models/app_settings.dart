/// Persistent app settings for SecondBrain MVP.
class AppSettings {
  const AppSettings({
    this.vaultPath = '',
    this.ollamaBaseUrl = 'http://127.0.0.1:11434',
    this.modelName = 'qwen2.5:7b',
    this.systemPrompt = AppSettings.defaultSystemPrompt,
  });

  final String vaultPath;
  final String ollamaBaseUrl;
  final String modelName;
  final String systemPrompt;

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

  AppSettings copyWith({
    String? vaultPath,
    String? ollamaBaseUrl,
    String? modelName,
    String? systemPrompt,
  }) {
    return AppSettings(
      vaultPath: vaultPath ?? this.vaultPath,
      ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
      modelName: modelName ?? this.modelName,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    );
  }

  Map<String, dynamic> toJson() => {
        'vaultPath': vaultPath,
        'ollamaBaseUrl': ollamaBaseUrl,
        'modelName': modelName,
        'systemPrompt': systemPrompt,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      vaultPath: json['vaultPath'] as String? ?? '',
      ollamaBaseUrl:
          json['ollamaBaseUrl'] as String? ?? 'http://127.0.0.1:11434',
      modelName: json['modelName'] as String? ?? 'qwen2.5:7b',
      systemPrompt:
          json['systemPrompt'] as String? ?? AppSettings.defaultSystemPrompt,
    );
  }
}
