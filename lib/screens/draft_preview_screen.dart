import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/chat_message.dart';
import '../state/app_controller.dart';

/// Preview multi-file note drafts before approve / reject.
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
        SnackBar(content: Text('Записано: ${written.join(', ')}')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка записи: $e')),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Черновик (${files.length} файл(ов))'),
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: files.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final f = files[i];
                  final selected = i == _index;
                  return ChoiceChip(
                    label: Text('${f.op}: ${f.path}'),
                    selected: selected,
                    onSelected: (_) => setState(() => _index = i),
                  );
                },
              ),
            ),
          ),
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
                              fontFamilyFallback: ['Courier New', 'monospace'],
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
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Запись в vault только после «Утвердить». '
                    'Файлы пишутся атомарно (temp → rename).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _reject,
                  child: const Text('Отклонить'),
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
                      : const Text('Утвердить'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
