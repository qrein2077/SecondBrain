import 'package:material_ui/material_ui.dart';

import '../services/wiki_link.dart';
import '../state/app_controller.dart';

/// Renders text with clickable `[[wiki-links]]` and hover preview on desktop.
class WikiText extends StatelessWidget {
  const WikiText({
    super.key,
    required this.text,
    required this.controller,
    this.style,
  });

  final String text;
  final AppController controller;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final linkStyle = base.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: Theme.of(context).colorScheme.primary,
    );

    final spans = <InlineSpan>[];
    var start = 0;
    for (final m in WikiLink.pattern.allMatches(text)) {
      if (m.start > start) {
        spans.add(TextSpan(text: text.substring(start, m.start), style: base));
      }
      final inner = m.group(1)!;
      final target = WikiLink.targetOf(inner);
      final label = WikiLink.displayOf(inner);
      final resolved =
          WikiLink.resolve(target, controller.markdownFiles);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _WikiChip(
            label: label,
            target: target,
            resolvedPath: resolved,
            style: linkStyle,
            controller: controller,
          ),
        ),
      );
      start = m.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: base));
    }

    return Text.rich(TextSpan(children: spans));
  }
}

class _WikiChip extends StatefulWidget {
  const _WikiChip({
    required this.label,
    required this.target,
    required this.resolvedPath,
    required this.style,
    required this.controller,
  });

  final String label;
  final String target;
  final String? resolvedPath;
  final TextStyle style;
  final AppController controller;

  @override
  State<_WikiChip> createState() => _WikiChipState();
}

class _WikiChipState extends State<_WikiChip> {
  final _linkKey = GlobalKey();
  OverlayEntry? _overlay;

  void _hide() {
    _overlay?.remove();
    _overlay = null;
  }

  Future<void> _showPreview() async {
    _hide();
    final path = widget.resolvedPath;
    if (path == null) return;
    String snippet = path;
    try {
      final v = widget.controller.vault;
      if (v != null) {
        final body = await v.readNote(path);
        snippet = body.length > 400 ? '${body.substring(0, 400)}…' : body;
      }
    } catch (e) {
      snippet = 'Не удалось прочитать: $e';
    }
    if (!mounted) return;

    final box = _linkKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final offset = box.localToGlobal(Offset.zero, ancestor: overlay);

    _overlay = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          left: offset.dx.clamp(8.0, overlay.size.width - 320),
          top: (offset.dy + box.size.height + 4)
              .clamp(8.0, overlay.size.height - 180),
          width: 300,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    path,
                    style: Theme.of(ctx).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    snippet,
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlay!);
  }

  Future<void> _open() async {
    _hide();
    final path = widget.resolvedPath;
    if (path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Заметка «${widget.target}» не найдена в vault')),
      );
      return;
    }
    try {
      await widget.controller.openNote(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не открыть $path: $e')),
      );
    }
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final missing = widget.resolvedPath == null;
    return MouseRegion(
      onEnter: (_) => _showPreview(),
      onExit: (_) => _hide(),
      child: GestureDetector(
        key: _linkKey,
        onTap: _open,
        onLongPress: _showPreview,
        child: Text(
          '[[${widget.label}]]',
          style: widget.style.copyWith(
            color: missing
                ? Theme.of(context).colorScheme.error
                : widget.style.color,
            fontStyle: missing ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }
}
