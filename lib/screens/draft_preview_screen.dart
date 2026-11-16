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

  Future<bool> _confirmDeletesIfNeeded() async {
    final deletes = widget.bundle.files.where((f) => f.isDelete).toList();
    if (deletes.isEmpty) return true;
    final paths = deletes.map((d) => d.path).join('\n• ');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтвердите удаление'),
        content: SingleChildScrollView(
          child: Text(
            'Будут удалены ${deletes.length} файл(ов) '
            '(на Windows — в Корзину, если возможно):\n\n• $paths\n\n'
            'Без этого подтверждения удаление не выполнится. '
            'Создание/обновление в том же пакете применятся вместе с удалениями.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить и утвердить'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _approve() async {
    final confirmed = await _confirmDeletesIfNeeded();
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      widget.controller.setPendingDraft(widget.bundle);
      final written = await widget.controller.approvePendingDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Пакет применён (${written.length}): ${written.join(', ')}',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка пакета: $e')),
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

  IconData _opIcon(NoteDraft f) {
    if (f.isDelete) return Icons.delete_forever;
    if (f.isUpdate) return Icons.edit_note;
    return Icons.note_add_outlined;
  }

  Color? _opColor(BuildContext context, NoteDraft f) {
    if (f.isDelete) return Theme.of(context).colorScheme.error;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final files = widget.bundle.files;
    final n = files.length;
    final delN = widget.bundle.deleteCount;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          delN > 0
              ? 'Пакет · $n · удалений: $delN'
              : 'Пакет черновика · $n файл(ов)',
        ),
      ),
      body: Column(
        children: [
          Material(
            color: delN > 0
                ? scheme.errorContainer
                : scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                delN > 0
                    ? 'В пакете есть удаления (красные «удалить»). '
                        '«Утвердить все» сначала попросит подтверждение; '
                        'на Windows файлы по возможности уйдут в Корзину. '
                        'В режиме «Только ответы» удаления запрещены.'
                    : 'Агент предлагает изменения по всему vault. '
                        '«Утвердить все» запишет весь пакет; '
                        '«Отклонить все» — ничего не изменит.',
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
                    color: scheme.surfaceContainerLow,
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
                              final color = _opColor(context, f);
                              return ListTile(
                                dense: true,
                                selected: selected,
                                leading: Icon(
                                  _opIcon(f),
                                  size: 20,
                                  color: color,
                                ),
                                title: Text(
                                  f.path,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: color,
                                    fontWeight: f.isDelete
                                        ? FontWeight.w600
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  f.opLabelRu,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: color,
                                    fontWeight: f.isDelete
                                        ? FontWeight.w700
                                        : null,
                                  ),
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
                  child: _current.isDelete
                      ? _DeletePreview(path: _current.path)
                      : Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      'Markdown — ${_current.path}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
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
                    delN > 0
                        ? 'Сначала create/update (temp→rename), затем delete. '
                            'Удаления — только после подтверждения.'
                        : 'Пакет: $n файл(ов). Сначала стейджинг всех, потом commit.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _reject,
                  child: Text('Отклонить все ($n)'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: delN > 0
                      ? FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                        )
                      : null,
                  onPressed: _busy ? null : _approve,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          delN > 0
                              ? 'Утвердить все ($n, удал. $delN)'
                              : 'Утвердить все ($n)',
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeletePreview extends StatelessWidget {
  const _DeletePreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_forever, size: 48, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              'удалить',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              path,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Файл будет удалён из vault после «Утвердить все» '
              'и подтверждения в диалоге. На Windows — по возможности в Корзину.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
