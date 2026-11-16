import 'package:material_ui/material_ui.dart';

import '../models/chat_message.dart';
import '../models/cloud_provider.dart';
import '../models/llm_mode.dart';
import '../screens/draft_preview_screen.dart';
import '../state/app_controller.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key, required this.controller});

  final AppController controller;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  AppController get c => widget.controller;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    _input.clear();
    await c.sendChat(text);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    if (c.pendingDraft != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DraftPreviewScreen(
            controller: c,
            bundle: c.pendingDraft!,
          ),
        ),
      );
    }
  }

  Color _bubbleColor(BuildContext context, ChatRole role) {
    final scheme = Theme.of(context).colorScheme;
    switch (role) {
      case ChatRole.user:
        return scheme.primaryContainer;
      case ChatRole.assistant:
        return scheme.surfaceContainerHighest;
      case ChatRole.system:
        return scheme.tertiaryContainer;
      case ChatRole.error:
        return scheme.errorContainer;
    }
  }

  String _roleLabel(ChatRole role) {
    switch (role) {
      case ChatRole.user:
        return 'Вы';
      case ChatRole.assistant:
        return 'Агент';
      case ChatRole.system:
        return 'Система';
      case ChatRole.error:
        return 'Ошибка';
    }
  }

  String _backendStatus(AppController c) {
    final parts = <String>[];
    parts.add(c.ollamaOnline ? 'Ollama' : 'Ollama∅');
    final cloud = c.settings.cloudProvider.shortLabel;
    if (c.settingsStore.hasKeyFor(c.settings.cloudProvider)) {
      parts.add(c.cloudReachable ? cloud : '$cloud?');
    } else {
      parts.add('$cloud∅');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Чат с агентом',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                c.ollamaOnline || c.cloudReachable
                    ? Icons.circle
                    : Icons.circle_outlined,
                size: 12,
                color: c.ollamaOnline || c.cloudReachable
                    ? Colors.green
                    : Colors.grey,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _backendStatus(c),
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Проверить LLM',
                onPressed: () => c.checkBackends(),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.wifi_tethering, size: 20),
              ),
              IconButton(
                tooltip: 'Очистить чат',
                onPressed: c.chat.isEmpty ? null : () => c.clearChat(),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 20),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${c.settings.llmMode.labelRu} · ${c.activeModelLabel} · concurrency 1',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (c.pendingDraft != null)
          Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Пакет: ${c.pendingDraft!.files.length} файл(ов) — '
                      '${c.pendingDraft!.files.map((f) => f.path).take(3).join(', ')}'
                      '${c.pendingDraft!.files.length > 3 ? '…' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DraftPreviewScreen(
                            controller: c,
                            bundle: c.pendingDraft!,
                          ),
                        ),
                      );
                    },
                    child: const Text('Открыть'),
                  ),
                  TextButton(
                    onPressed: () => c.rejectPendingDraft(),
                    child: const Text('Отклонить все'),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: c.chat.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Напишите идею или вопрос.\n'
                      'Агент работает со ВСЕМ vault и может предложить '
                      'несколько связанных .md с [[wiki-links]].\n'
                      'Запись в vault — только после «Утвердить все».\n'
                      'Голосовой ввод (Whisper) пока не реализован.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: c.chat.length,
                  itemBuilder: (context, index) {
                    final m = c.chat[index];
                    return Align(
                      alignment: m.role == ChatRole.user
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(maxWidth: 420),
                        decoration: BoxDecoration(
                          color: _bubbleColor(context, m.role),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _roleLabel(m.role),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(height: 4),
                            SelectableText(m.content),
                            if (m.draftBundle != null &&
                                m.draftBundle!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  c.setPendingDraft(m.draftBundle);
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => DraftPreviewScreen(
                                        controller: c,
                                        bundle: m.draftBundle!,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.preview, size: 16),
                                label: Text(
                                  'Пакет ${m.draftBundle!.files.length} файл.',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 5,
                  enabled: !c.chatBusy,
                  decoration: const InputDecoration(
                    hintText: 'Идея для vault (можно несколько заметок)…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) {
                    if (!c.chatBusy) _send();
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: c.chatBusy ? null : _send,
                child: c.chatBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
