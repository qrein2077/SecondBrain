import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:saf/saf.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/agent_preset.dart';
import '../models/app_settings.dart';
import '../models/cloud_provider.dart';
import '../models/llm_mode.dart';
import '../models/whisper_size.dart';
import '../services/update_checker.dart';
import '../services/whisper_stt_service.dart';
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
  late bool _qaOnly;
  late WhisperSize _whisperSize;
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
    _qaOnly = s.qaOnly;
    _whisperSize = s.whisperSize;
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
    // Android: SAF document tree with persistable read/write grant.
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final saf = Saf();
        final dir = await saf.pickDirectory(
          writePermission: true,
          persistablePermission: true,
        );
        if (dir != null && mounted) {
          setState(() => _vaultCtrl.text = dir.uri);
        }
        return;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('SAF: $e — пробуем file_picker…')),
          );
        }
      }
    }
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Выберите папку Obsidian vault',
    );
    if (path != null && mounted) {
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
          qaOnly: _qaOnly,
          whisperSize: _whisperSize,
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

  Future<void> _applyPreset(String id) async {
    await widget.controller.selectAgentPreset(id);
    setState(() {
      _promptCtrl.text = widget.controller.settings.systemPrompt;
    });
  }

  Future<void> _saveCurrentAsPreset() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сохранить пресет'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Название',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(nameCtrl.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (name == null || name.trim().isEmpty) return;
    final preset = AgentPreset(
      id: 'p_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      systemPrompt: _promptCtrl.text.trim().isEmpty
          ? AppSettings.defaultSystemPrompt
          : _promptCtrl.text,
    );
    await widget.controller.settingsStore.savePreset(preset);
    await _applyPreset(preset.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пресет «${preset.name}» сохранён')),
      );
    }
  }

  Future<void> _updateActivePresetPrompt() async {
    final id = widget.controller.activePresetId;
    final existing = widget.controller.agentPresets.firstWhere(
      (p) => p.id == id,
      orElse: () => AgentPreset.clarifyingDefault,
    );
    await widget.controller.settingsStore.savePreset(
      existing.copyWith(
        systemPrompt: _promptCtrl.text.trim().isEmpty
            ? AppSettings.defaultSystemPrompt
            : _promptCtrl.text,
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пресет обновлён')),
      );
      setState(() {});
    }
  }

  Future<void> _checkUpdates() async {
    final result = await UpdateChecker().check(currentVersion: '1.0.0');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Обновления'),
        content: Text(result.message),
        actions: [
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(result.actionsUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Actions'),
          ),
          if (result.releaseUrl != null)
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(result.releaseUrl!),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Release'),
            ),
          if (result.downloadUrl != null)
            FilledButton(
              onPressed: () => launchUrl(
                Uri.parse(result.downloadUrl!),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Скачать .exe'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
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
          const SizedBox(height: 4),
          Text(
            !kIsWeb && Platform.isAndroid
                ? 'Android: «Обзор» → SAF (папка Obsidian). URI content:// '
                    'с постоянным разрешением. Удаления в SAF — без корзины.'
                : 'Укажите локальную папку Obsidian vault.',
            style: Theme.of(context).textTheme.bodySmall,
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
            'Режим агента',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _qaOnly ? 'Только ответы' : 'Может править vault',
            ),
            subtitle: Text(
              _qaOnly
                  ? 'Без PROPOSE_NOTES и без панели черновиков.'
                  : 'Сначала уточняющие вопросы, затем пакет заметок → Утвердить.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: _qaOnly,
            onChanged: (v) => setState(() => _qaOnly = v),
          ),
          const SizedBox(height: 16),
          Text(
            WhisperSttService.isSupported
                ? 'Голосовой ввод (Whisper)'
                : 'Голосовой ввод',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            WhisperSttService.isSupported
                ? 'Локальный whisper.cpp (ggml). Язык всегда ru. '
                    'Модель скачивается при первом использовании '
                    '(не входит в APK/установщик). '
                    '${WhisperSttService.platformHint}'
                : 'Микрофон на этой платформе скрыт. Используйте Windows/Android '
                    'или вводите текст вручную.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (WhisperSttService.isSupported) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<WhisperSize>(
              // ignore: deprecated_member_use
              value: _whisperSize,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Размер модели Whisper',
              ),
              items: [
                for (final s in WhisperSize.values)
                  DropdownMenuItem(value: s, child: Text(s.labelRu)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _whisperSize = v);
              },
            ),
            const SizedBox(height: 6),
            Text(
              _whisperSize == WhisperSize.medium
                  ? '⚠ medium: ${_whisperSize.downloadHint}. '
                      'На слабом ПК/телефоне лучше small или base.'
                  : _whisperSize.downloadHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _whisperSize == WhisperSize.medium
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Локальный LLM (Ollama)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'На Android укажите IP ПК в LAN или Tailscale '
            '(например http://100.x.y.z:11434). Cleartext HTTP разрешён. '
            'Либо режим Облако (Groq/OpenRouter/Gemini).',
            style: Theme.of(context).textTheme.bodySmall,
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
                  'Напр. openai/gpt-oss-20b, openai/gpt-oss-120b, qwen/qwen3.6-27b',
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
          const Text(
            'Пресеты агента',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Default — «Уточняющий» (clarifying). Можно сохранить свои '
            'именованные system prompt и переключаться.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: widget.controller.activePresetId,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Активный пресет',
            ),
            items: [
              for (final p in widget.controller.agentPresets)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (id) {
              if (id != null) _applyPreset(id);
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _saveCurrentAsPreset,
                child: const Text('Сохранить как пресет'),
              ),
              TextButton(
                onPressed: _updateActivePresetPrompt,
                child: const Text('Обновить текущий'),
              ),
              TextButton(
                onPressed: widget.controller.activePresetId ==
                        AgentPreset.defaultPresetId
                    ? null
                    : () async {
                        await widget.controller.settingsStore
                            .deletePreset(widget.controller.activePresetId);
                        setState(() {
                          _promptCtrl.text =
                              widget.controller.settings.systemPrompt;
                        });
                      },
                child: const Text('Удалить пресет'),
              ),
              TextButton(
                onPressed: _resetPrompt,
                child: const Text('Сбросить текст'),
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
              labelText: 'System prompt',
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Обновления',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Сначала GitHub Releases; если Release нет — скачайте артефакт '
            'SecondBrain-Setup-Windows из Actions (unsigned OK).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _checkUpdates,
            icon: const Icon(Icons.system_update_alt),
            label: const Text('Проверить обновления'),
          ),
        ],
      ),
    );
  }
}
