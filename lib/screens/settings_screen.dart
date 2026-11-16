import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../models/app_settings.dart';
import '../models/llm_mode.dart';
import '../state/app_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _vaultCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _geminiModelCtrl;
  late final TextEditingController _geminiKeyCtrl;
  late final TextEditingController _promptCtrl;
  late LlmMode _llmMode;
  bool _saving = false;
  bool _obscureKey = true;
  bool _clearKey = false;

  @override
  void initState() {
    super.initState();
    final s = widget.controller.settings;
    _vaultCtrl = TextEditingController(text: s.vaultPath);
    _urlCtrl = TextEditingController(text: s.ollamaBaseUrl);
    _modelCtrl = TextEditingController(text: s.modelName);
    _geminiModelCtrl = TextEditingController(text: s.geminiModel);
    _geminiKeyCtrl = TextEditingController();
    _promptCtrl = TextEditingController(text: s.systemPrompt);
    _llmMode = s.llmMode;
  }

  @override
  void dispose() {
    _vaultCtrl.dispose();
    _urlCtrl.dispose();
    _modelCtrl.dispose();
    _geminiModelCtrl.dispose();
    _geminiKeyCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVault() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Выберите папку Obsidian vault',
    );
    if (path != null) {
      setState(() => _vaultCtrl.text = path);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final keyTyped = _geminiKeyCtrl.text.trim();
      await widget.controller.saveSettings(
        AppSettings(
          vaultPath: _vaultCtrl.text.trim(),
          ollamaBaseUrl: _urlCtrl.text.trim().isEmpty
              ? 'http://127.0.0.1:11434'
              : _urlCtrl.text.trim(),
          modelName: _modelCtrl.text.trim().isEmpty
              ? 'qwen2.5:7b'
              : _modelCtrl.text.trim(),
          geminiModel: _geminiModelCtrl.text.trim().isEmpty
              ? AppSettings.defaultGeminiModel
              : _geminiModelCtrl.text.trim(),
          llmMode: _llmMode,
          systemPrompt: _promptCtrl.text.trim().isEmpty
              ? AppSettings.defaultSystemPrompt
              : _promptCtrl.text,
        ),
        geminiApiKey: _clearKey
            ? ''
            : (keyTyped.isEmpty ? null : keyTyped),
        clearGeminiApiKey: _clearKey,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Настройки сохранены')),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetPrompt() {
    setState(() => _promptCtrl.text = AppSettings.defaultSystemPrompt);
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = widget.controller.settingsStore.hasGeminiApiKey && !_clearKey;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Сохранить'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Vault',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _vaultCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Путь к папке vault',
                    border: OutlineInputBorder(),
                    hintText: r'C:\Users\...\ObsidianVault',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _pickVault,
                child: const Text('Обзор…'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Remotely Save не трогаем — работаем только с локальной копией vault.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          const Text(
            'Режим LLM',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<LlmMode>(
            // ignore: deprecated_member_use
            value: _llmMode,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Режим',
            ),
            items: [
              for (final m in LlmMode.values)
                DropdownMenuItem(value: m, child: Text(m.labelRu)),
            ],
            onChanged: (m) {
              if (m != null) setState(() => _llmMode = m);
            },
          ),
          const SizedBox(height: 8),
          Text(
            'По умолчанию — локальный Ollama (Qwen2.5). '
            'Gemini (Google AI Studio) — опционально: cloud или auto '
            '(если Ollama недоступна). Запись в vault по-прежнему только после Approve.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          const Text(
            'Локальный LLM (Ollama)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'Ollama base URL',
              border: OutlineInputBorder(),
              hintText: 'http://127.0.0.1:11434',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelCtrl,
            decoration: const InputDecoration(
              labelText: 'Модель Ollama',
              border: OutlineInputBorder(),
              hintText: 'qwen2.5:7b',
              helperText: 'Рекомендуется Qwen2.5 7B–8B Q4/Q5',
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Облако — Google Gemini (AI Studio)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Ключ хранится в защищённом хранилище устройства '
            '(не в vault и не в git). Используется OpenAI-совместимый endpoint '
            'generativelanguage.googleapis.com/v1beta/openai/.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _geminiModelCtrl,
            decoration: const InputDecoration(
              labelText: 'Модель Gemini (вручную)',
              border: OutlineInputBorder(),
              hintText: AppSettings.defaultGeminiModel,
              helperText:
                  'Напр. gemini-2.5-flash, gemini-2.5-pro, gemini-3.8-flash',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _geminiKeyCtrl,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: hasKey
                  ? 'API-ключ Gemini (оставьте пустым, чтобы не менять)'
                  : 'API-ключ Gemini',
              border: const OutlineInputBorder(),
              hintText: hasKey ? '•••••••• (уже сохранён)' : 'AIza…',
              suffixIcon: IconButton(
                tooltip: _obscureKey ? 'Показать' : 'Скрыть',
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
                icon: Icon(
                  _obscureKey ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (hasKey)
                Text(
                  'Ключ сохранён на устройстве',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const Spacer(),
              if (hasKey || _clearKey)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _clearKey = !_clearKey;
                      if (_clearKey) _geminiKeyCtrl.clear();
                    });
                  },
                  child: Text(_clearKey ? 'Отмена удаления' : 'Удалить ключ'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'System prompt агента',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              TextButton(
                onPressed: _resetPrompt,
                child: const Text('Сбросить'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Один и тот же prompt для Ollama и Gemini. '
            'Агент работает со всем vault (пакет create/update + [[wiki-links]]).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _promptCtrl,
            maxLines: 14,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}
