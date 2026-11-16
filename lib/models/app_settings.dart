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

  static const defaultSystemPrompt = '''
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
