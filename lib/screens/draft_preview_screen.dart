import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/chat_message.dart';
import '../state/app_controller.dart';

/// Preview multi-file note drafts before approve / reject (whole batch).
class DraftPreviewScreen extends StatefulWidget {
  const DraftPreviewScreen({
    super.key,
    required this.controller,
    required this.bundle,
  });

  final AppController controller;
  final NoteDraftBundle bundle;

  @override
  State<DraftPreviewScreen> createState() => _DraftPreviewScreenState();
}

class _DraftPreviewScreenState extends State<DraftPreviewScreen> {
  late int _index;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _index = 0;
  }

  NoteDraft get _current => widget.bundle.files[_index];

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      widget.controller.setPendingDraft(widget.bundle);
      final written = await widget.controller.approvePendingDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Записан пакет (${written.length}): ${written.join(', ')}',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка записи пакета: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reject() {
    widget.controller.setPendingDraft(widget.bundle);
    widget.controller.rejectPendingDraft();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final files = widget.bundle.files;
    final n = files.length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Пакет черновика · $n файл(ов)'),
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Агент предлагает изменения по всему vault (не только открытая заметка). '
                '«Утвердить все» запишет весь пакет; «Отклонить все» — ничего не изменит.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 280,
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          child: Text(
                            'Файлы в пакете',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: files.length,
                            itemBuilder: (context, i) {
                              final f = files[i];
                              final selected = i == _index;
                              return ListTile(
                                dense: true,
                                selected: selected,
                                leading: Icon(
                                  f.op == 'update'
                                      ? Icons.edit_note
                                      : Icons.note_add_outlined,
                                  size: 20,
                                ),
                                title: Text(
                                  f.path,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(
                                  f.op == 'update' ? 'update' : 'create',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onTap: () => setState(() => _index = i),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'Markdown — ${_current.path}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(12),
                                child: SelectableText(
                                  _current.content,
                                  style: const TextStyle(
                                    fontFamily: 'Consolas',
                                    fontFamilyFallback: [
                                      'Courier New',
                                      'monospace',
                                    ],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'Превью',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            Expanded(
                              child: Markdown(
                                data: _current.content,
                                selectable: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Пакет: $n файл(ов). Каждый файл — temp→rename; '
                    'сначала стейджинг всех, потом commit.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _reject,
                  child: Text('Отклонить все ($n)'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _approve,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Утвердить все ($n)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
