import 'package:material_ui/material_ui.dart';

import '../models/chat_message.dart';
import '../models/cloud_provider.dart';
import '../models/llm_mode.dart';
import '../screens/draft_preview_screen.dart';
import '../services/whisper_stt_service.dart';
import '../state/app_controller.dart';
import 'wiki_text.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key, required this.controller});

  final AppController controller;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _stt = WhisperSttService();
  bool _recording = false;
  bool _transcribing = false;
  String? _sttError;

  AppController get c => widget.controller;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _stt.dispose();
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
    if (!c.settings.qaOnly && c.pendingDraft != null && mounted) {
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

  Future<void> _toggleMic() async {
    if (!WhisperSttService.isSupported) return;
    setState(() => _sttError = null);
    try {
      if (_recording) {
        setState(() {
          _recording = false;
          _transcribing = true;
        });
        final text = await _stt.stopAndTranscribe(lang: 'ru');
        if (!mounted) return;
        if (text.isNotEmpty) {
          final cur = _input.text;
          _input.text = cur.trim().isEmpty ? text : '$cur $text';
          _input.selection = TextSelection.collapsed(offset: _input.text.length);
        } else {
          setState(() => _sttError = 'Пустая расшифровка — попробуйте ещё раз.');
        }
      } else {
        setState(() => _transcribing = true);
        // Warm model on first use (download ggml-base.bin once).
        await _stt.ensureModel();
        await _stt.startRecording();
        if (!mounted) return;
        setState(() {
          _recording = true;
          _transcribing = false;
        });
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recording = false;
          _sttError = e.toString();
        });
        await _stt.cancelRecording();
      }
    } finally {
      if (mounted) setState(() => _transcribing = false);
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

  Future<void> _renameSession(BuildContext context) async {
    final s = c.activeSession;
    if (s == null) return;
    final ctrl = TextEditingController(text: s.title);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Переименовать чат'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name != null) await c.renameSession(s.id, name);
  }

  String _emptyHint() {
    if (c.settings.qaOnly) {
      return 'Режим «Только ответы»: спросите, например, '
          '«что я уже знаю по физике» — агент ответит по заметкам vault '
          '(RAG-lite), не отправит вас открывать файлы сами.\n'
          '${WhisperSttService.isSupported ? 'Микрофон: локальный Whisper (base).\n' : ''}'
          'Для правок заметок переключите на «Может править vault».';
    }
    return 'Напишите идею или вопрос.\n'
        'Вопросы о знаниях отвечаются по выдержкам из vault; '
        'для правок агент сначала уточнит, затем предложит пакет .md.\n'
        'Запись в vault — только после «Утвердить все».\n'
        '${WhisperSttService.isSupported ? 'Микрофон → Whisper → текст в поле ввода.' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final showMic = WhisperSttService.isSupported;
    final micBusy = _transcribing || c.chatBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Чат',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                c.activeRouteOnline ? Icons.circle : Icons.circle_outlined,
                size: 12,
                color: c.activeRouteOnline ? Colors.green : Colors.redAccent,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${_backendStatus(c)} · ${c.activeRouteLabel}',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Новый чат',
                onPressed: c.chatBusy ? null : () => c.createSession(),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_comment_outlined, size: 20),
              ),
              IconButton(
                tooltip: 'Очистить текущий чат',
                onPressed:
                    c.chat.isEmpty ? null : () => c.clearChat(),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 20),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: c.activeSession?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: 'Сессия',
                  ),
                  items: [
                    for (final s in c.sessions)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          s.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: c.chatBusy
                      ? null
                      : (id) {
                          if (id != null) c.switchSession(id);
                        },
                ),
              ),
              IconButton(
                tooltip: 'Переименовать сессию',
                onPressed: c.activeSession == null
                    ? null
                    : () => _renameSession(context),
                icon: const Icon(Icons.drive_file_rename_outline, size: 20),
              ),
              IconButton(
                tooltip: 'Удалить сессию',
                onPressed: c.activeSession == null
                    ? null
                    : () => c.deleteSession(c.activeSession!.id),
                icon: const Icon(Icons.playlist_remove, size: 20),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Text(
            '${c.settings.llmMode.labelRu} · ${c.activeModelLabel} · '
            'пресет: ${c.settingsStore.activePreset.name}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                label: Text('Только ответы'),
                icon: Icon(Icons.chat_bubble_outline, size: 16),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('Может править vault'),
                icon: Icon(Icons.edit_note, size: 16),
              ),
            ],
            selected: {c.settings.qaOnly},
            onSelectionChanged: c.chatBusy
                ? null
                : (set) {
                    final v = set.first;
                    c.setQaOnly(v);
                  },
          ),
        ),
        if (!c.settings.qaOnly && c.pendingDraft != null)
          Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Пакет: ${c.pendingDraft!.files.length} '
                      '(уд. ${c.pendingDraft!.deleteCount}) — '
                      '${c.pendingDraft!.files.map((f) => f.isDelete ? '✕${f.path}' : f.path).take(3).join(', ')}'
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _emptyHint(),
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
                    final showDraft = !c.settings.qaOnly &&
                        m.draftBundle != null &&
                        m.draftBundle!.isNotEmpty;
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
                            if (m.role == ChatRole.assistant ||
                                m.role == ChatRole.user)
                              WikiText(text: m.content, controller: c)
                            else
                              SelectableText(m.content),
                            if (m.role == ChatRole.assistant &&
                                m.sources.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Источники',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  for (final src in m.sources.take(8))
                                    ActionChip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(
                                        src,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      onPressed: () => c.openNote(src),
                                    ),
                                ],
                              ),
                            ],
                            if (showDraft) ...[
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
                                  m.draftBundle!.hasDeletes
                                      ? 'Пакет ${m.draftBundle!.files.length} '
                                          '(уд. ${m.draftBundle!.deleteCount})'
                                      : 'Пакет ${m.draftBundle!.files.length} файл.',
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
        if (_sttError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _sttError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        if (_recording)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Идёт запись… Нажмите микрофон ещё раз, чтобы расшифровать.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (showMic) ...[
                IconButton.filledTonal(
                  tooltip: _recording
                      ? 'Стоп и расшифровать (Whisper)'
                      : 'Голос → Whisper → поле ввода',
                  onPressed: micBusy ? null : _toggleMic,
                  style: IconButton.styleFrom(
                    backgroundColor: _recording
                        ? Theme.of(context).colorScheme.errorContainer
                        : null,
                  ),
                  icon: _transcribing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_recording ? Icons.stop : Icons.mic),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 5,
                  enabled: !c.chatBusy && !_transcribing,
                  decoration: InputDecoration(
                    hintText: c.settings.qaOnly
                        ? 'Вопрос (без записи в vault)…'
                        : 'Идея для vault (сначала уточнения, потом черновик)…',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) {
                    if (!c.chatBusy && !_transcribing) _send();
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: (c.chatBusy || _transcribing) ? null : _send,
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
