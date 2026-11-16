import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../models/app_settings.dart';
import '../models/cloud_provider.dart';
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
  late final TextEditingController _groqModelCtrl;
  late final TextEditingController _openRouterModelCtrl;
  late final TextEditingController _geminiKeyCtrl;
  late final TextEditingController _groqKeyCtrl;
  late final TextEditingController _openRouterKeyCtrl;
  late final TextEditingController _promptCtrl;
  late LlmMode _llmMode;
  late CloudProvider _cloudProvider;
  bool _saving = false;
  bool _obscureGemini = true;
  bool _obscureGroq = true;
  bool _obscureOpenRouter = true;
  bool _clearGemini = false;
  bool _clearGroq = false;
  bool _clearOpenRouter = false;

  @override
  void initState() {
    super.initState();
    final s = widget.controller.settings;
    _vaultCtrl = TextEditingController(text: s.vaultPath);
    _urlCtrl = TextEditingController(text: s.ollamaBaseUrl);
    _modelCtrl = TextEditingController(text: s.modelName);
    _geminiModelCtrl = TextEditingController(text: s.geminiModel);
    _groqModelCtrl = TextEditingController(text: s.groqModel);
    _openRouterModelCtrl = TextEditingController(text: s.openRouterModel);
    _geminiKeyCtrl = TextEditingController();
    _groqKeyCtrl = TextEditingController();
    _openRouterKeyCtrl = TextEditingController();
    _promptCtrl = TextEditingController(text: s.systemPrompt);
    _llmMode = s.llmMode;
    _cloudProvider = s.cloudProvider;
  }

  @override
  void dispose() {
    _vaultCtrl.dispose();
    _urlCtrl.dispose();
    _modelCtrl.dispose();
    _geminiModelCtrl.dispose();
    _groqModelCtrl.dispose();
    _openRouterModelCtrl.dispose();
    _geminiKeyCtrl.dispose();
    _groqKeyCtrl.dispose();
    _openRouterKeyCtrl.dispose();
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

  String? _keyArg(TextEditingController ctrl, bool clear) {
    if (clear) return '';
    final t = ctrl.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
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
          groqModel: _groqModelCtrl.text.trim().isEmpty
              ? AppSettings.defaultGroqModel
              : _groqModelCtrl.text.trim(),
          openRouterModel: _openRouterModelCtrl.text.trim().isEmpty
              ? AppSettings.defaultOpenRouterModel
              : _openRouterModelCtrl.text.trim(),
          llmMode: _llmMode,
          cloudProvider: _cloudProvider,
          systemPrompt: _promptCtrl.text.trim().isEmpty
              ? AppSettings.defaultSystemPrompt
              : _promptCtrl.text,
        ),
        geminiApiKey: _keyArg(_geminiKeyCtrl, _clearGemini),
        groqApiKey: _keyArg(_groqKeyCtrl, _clearGroq),
        openRouterApiKey: _keyArg(_openRouterKeyCtrl, _clearOpenRouter),
        clearGeminiApiKey: _clearGemini,
        clearGroqApiKey: _clearGroq,
        clearOpenRouterApiKey: _clearOpenRouter,
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

  Widget _keyField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required bool hasSaved,
    required bool clear,
    required VoidCallback onToggleClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            labelText: hasSaved && !clear
                ? '$label (оставьте пустым, чтобы не менять)'
                : label,
            border: const OutlineInputBorder(),
            hintText: hasSaved && !clear ? '•••••••• (уже сохранён)' : null,
            suffixIcon: IconButton(
              onPressed: onToggleObscure,
              icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
            ),
          ),
        ),
        if (hasSaved || clear)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onToggleClear,
              child: Text(clear ? 'Отмена удаления' : 'Удалить ключ'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.controller.settingsStore;
    final hasGemini = store.hasGeminiApiKey && !_clearGemini;
    final hasGroq = store.hasGroqApiKey && !_clearGroq;
    final hasOr = store.hasOpenRouterApiKey && !_clearOpenRouter;

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
            'По умолчанию — локальный Ollama. '
            'Облако / Авто используют выбранного провайдера ниже '
            '(Gemini может быть недоступен в РФ — попробуйте Groq или OpenRouter).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<CloudProvider>(
            // ignore: deprecated_member_use
            value: _cloudProvider,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Облачный провайдер',
            ),
            items: [
              for (final p in CloudProvider.values)
                DropdownMenuItem(value: p, child: Text(p.labelRu)),
            ],
            onChanged: (p) {
              if (p != null) setState(() => _cloudProvider = p);
            },
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
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Groq',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'OpenAI-совместимый API: api.groq.com/openai/v1 — часто доступен из РФ. '
            'Ключ: console.groq.com',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _groqModelCtrl,
            decoration: const InputDecoration(
              labelText: 'Модель Groq',
              border: OutlineInputBorder(),
              hintText: AppSettings.defaultGroqModel,
              helperText:
                  'Напр. llama-3.1-8b-instant, llama-3.3-70b-versatile, openai/gpt-oss-20b',
            ),
          ),
          const SizedBox(height: 8),
          _keyField(
            label: 'API-ключ Groq',
            controller: _groqKeyCtrl,
            obscure: _obscureGroq,
            onToggleObscure: () =>
                setState(() => _obscureGroq = !_obscureGroq),
            hasSaved: hasGroq,
            clear: _clearGroq,
            onToggleClear: () => setState(() {
              _clearGroq = !_clearGroq;
              if (_clearGroq) _groqKeyCtrl.clear();
            }),
          ),
          const SizedBox(height: 24),
          const Text(
            'OpenRouter',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'OpenAI-совместимый API: openrouter.ai/api/v1. '
            'Бесплатные модели с суффиксом :free. Ключ: openrouter.ai/keys',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _openRouterModelCtrl,
            decoration: const InputDecoration(
              labelText: 'Модель OpenRouter',
              border: OutlineInputBorder(),
              hintText: AppSettings.defaultOpenRouterModel,
              helperText:
                  'Напр. meta-llama/llama-3.1-8b-instruct:free, google/gemma-3-27b-it:free',
            ),
          ),
          const SizedBox(height: 8),
          _keyField(
            label: 'API-ключ OpenRouter',
            controller: _openRouterKeyCtrl,
            obscure: _obscureOpenRouter,
            onToggleObscure: () =>
                setState(() => _obscureOpenRouter = !_obscureOpenRouter),
            hasSaved: hasOr,
            clear: _clearOpenRouter,
            onToggleClear: () => setState(() {
              _clearOpenRouter = !_clearOpenRouter;
              if (_clearOpenRouter) _openRouterKeyCtrl.clear();
            }),
          ),
          const SizedBox(height: 24),
          const Text(
            'Google Gemini (AI Studio)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Может быть недоступен в некоторых регионах (в т.ч. РФ). '
            'Если не работает — используйте Groq или OpenRouter.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _geminiModelCtrl,
            decoration: const InputDecoration(
              labelText: 'Модель Gemini',
              border: OutlineInputBorder(),
              hintText: AppSettings.defaultGeminiModel,
            ),
          ),
          const SizedBox(height: 8),
          _keyField(
            label: 'API-ключ Gemini',
            controller: _geminiKeyCtrl,
            obscure: _obscureGemini,
            onToggleObscure: () =>
                setState(() => _obscureGemini = !_obscureGemini),
            hasSaved: hasGemini,
            clear: _clearGemini,
            onToggleClear: () => setState(() {
              _clearGemini = !_clearGemini;
              if (_clearGemini) _geminiKeyCtrl.clear();
            }),
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
          const SizedBox(height: 8),
          TextField(
            controller: _promptCtrl,
            maxLines: 12,
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
