import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/wiki_link.dart';
import '../state/app_controller.dart';
import 'wiki_text.dart';

class NoteEditor extends StatefulWidget {
  const NoteEditor({super.key, required this.controller});

  final AppController controller;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final TextEditingController _textCtrl;
  String? _boundPath;
  bool _syncing = false;

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: c.editorText);
    _boundPath = c.selectedPath;
    c.addListener(_onAppChanged);
  }

  @override
  void didUpdateWidget(covariant NoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onAppChanged);
      widget.controller.addListener(_onAppChanged);
      _syncFromApp();
    }
  }

  void _onAppChanged() {
    if (!mounted) return;
    if (c.selectedPath != _boundPath ||
        (!_syncing && c.editorText != _textCtrl.text && !c.editorDirty)) {
      _syncFromApp();
    } else if (c.selectedPath != _boundPath) {
      _syncFromApp();
    }
    setState(() {});
  }

  void _syncFromApp() {
    _boundPath = c.selectedPath;
    _syncing = true;
    _textCtrl.value = TextEditingValue(
      text: c.editorText,
      selection: TextSelection.collapsed(offset: c.editorText.length),
    );
    _syncing = false;
  }

  @override
  void dispose() {
    c.removeListener(_onAppChanged);
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = c.selectedPath;

    if (path == null) {
      return const Center(
        child: Text('Выберите заметку слева или начните чат справа.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  path + (c.editorDirty ? ' •' : ''),
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: c.editorDirty
                    ? () async {
                        try {
                          await c.saveCurrentNote();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Сохранено')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ошибка: $e')),
                            );
                          }
                        }
                      }
                    : null,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Сохранить'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _textCtrl,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontFamilyFallback: ['Courier New', 'monospace'],
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Markdown…',
                      isDense: true,
                    ),
                    onChanged: (value) {
                      if (_syncing) return;
                      c.updateEditorText(value);
                    },
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Text(
                        'Превью',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    Expanded(
                      child: c.editorText.contains('[[')
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: WikiText(
                                text: c.editorText.isEmpty
                                    ? '_пусто_'
                                    : c.editorText,
                                controller: c,
                              ),
                            )
                          : Markdown(
                              data: c.editorText.isEmpty
                                  ? '_пусто_'
                                  : c.editorText,
                              selectable: true,
                              onTapLink: (text, href, title) {
                                if (href == null) return;
                                final target = href
                                    .replaceAll('%20', ' ')
                                    .replaceAll('.md', '');
                                final path = WikiLink.resolve(
                                  target,
                                  c.markdownFiles,
                                );
                                if (path != null) c.openNote(path);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
