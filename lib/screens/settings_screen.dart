import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../models/app_settings.dart';
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
  late final TextEditingController _promptCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.controller.settings;
    _vaultCtrl = TextEditingController(text: s.vaultPath);
    _urlCtrl = TextEditingController(text: s.ollamaBaseUrl);
    _modelCtrl = TextEditingController(text: s.modelName);
    _promptCtrl = TextEditingController(text: s.systemPrompt);
  }

  @override
  void dispose() {
    _vaultCtrl.dispose();
    _urlCtrl.dispose();
    _modelCtrl.dispose();
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
      await widget.controller.saveSettings(
        AppSettings(
          vaultPath: _vaultCtrl.text.trim(),
          ollamaBaseUrl: _urlCtrl.text.trim().isEmpty
              ? 'http://127.0.0.1:11434'
              : _urlCtrl.text.trim(),
          modelName: _modelCtrl.text.trim().isEmpty
              ? 'qwen2.5:7b'
              : _modelCtrl.text.trim(),
          systemPrompt: _promptCtrl.text.trim().isEmpty
              ? AppSettings.defaultSystemPrompt
              : _promptCtrl.text,
        ),
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
            'Remotely Save не трогаем — работаем только с локальной копией.',
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
              labelText: 'Модель',
              border: OutlineInputBorder(),
              hintText: 'qwen2.5:7b',
              helperText: 'Рекомендуется Qwen2.5 7B–8B Q4/Q5',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Облачные LLM API запрещены. Только локальный Ollama / совместимый endpoint.',
            style: Theme.of(context).textTheme.bodySmall,
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
            maxLines: 16,
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
