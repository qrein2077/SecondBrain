import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/cloud_provider.dart';
import '../services/update_checker.dart';
import '../state/app_controller.dart';
import '../widgets/chat_panel.dart';
import '../widgets/note_editor.dart';
import '../widgets/vault_browser.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  Future<void> _checkUpdates(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Проверка обновлений…')),
    );
    final result = await UpdateChecker().check(currentVersion: '1.0.0');
    if (!context.mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final online = controller.activeRouteOnline;
        return Scaffold(
          appBar: AppBar(
            title: const Text('SecondBrain'),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Tooltip(
                    message:
                        'Ollama: ${controller.ollamaOnline ? "online" : "offline"} · '
                        'Cloud ${controller.settings.cloudProvider.shortLabel}: '
                        '${controller.cloudReachable ? "ok" : "n/a"}'
                        '${controller.lastBackend != null ? " · last: ${controller.lastBackend!.label}" : ""}',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: online ? Colors.green : Colors.redAccent,
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Text(
                            '${controller.activeRouteLabel} · ${controller.activeModelLabel}',
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Проверить LLM',
                icon: const Icon(Icons.wifi_tethering),
                onPressed: () => controller.checkBackends(),
              ),
              IconButton(
                tooltip: 'Проверить обновления',
                icon: const Icon(Icons.system_update_alt),
                onPressed: () => _checkUpdates(context),
              ),
              IconButton(
                tooltip: 'Настройки',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          SettingsScreen(controller: controller),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Row(
            children: [
              SizedBox(
                width: 260,
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: VaultBrowser(controller: controller),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 3,
                child: NoteEditor(controller: controller),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 2,
                child: ChatPanel(controller: controller),
              ),
            ],
          ),
        );
      },
    );
  }
}
