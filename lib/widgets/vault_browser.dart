import 'package:material_ui/material_ui.dart';

import '../state/app_controller.dart';

class VaultBrowser extends StatelessWidget {
  const VaultBrowser({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final vaultPath = c.settings.vaultPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Vault',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Обновить',
                onPressed: c.loadingVault ? null : () => c.refreshVault(),
                icon: c.loadingVault
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (vaultPath.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Выберите папку vault в Настройках.',
              style: TextStyle(color: Colors.black54),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              vaultPath,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (c.vaultError != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                c.vaultError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: c.markdownFiles.isEmpty && !c.loadingVault
                ? const Center(child: Text('Нет .md файлов'))
                : ListView.builder(
                    itemCount: c.markdownFiles.length,
                    itemBuilder: (context, index) {
                      final path = c.markdownFiles[index];
                      final selected = path == c.selectedPath;
                      return ListTile(
                        dense: true,
                        selected: selected,
                        title: Text(
                          path,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        leading: const Icon(Icons.description_outlined, size: 18),
                        onTap: () async {
                          if (c.editorDirty) {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Несохранённые изменения'),
                                content: const Text(
                                  'Открыть другую заметку без сохранения?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Отмена'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Открыть'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true) return;
                          }
                          await c.openNote(path);
                        },
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}
