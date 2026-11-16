import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/cloud_provider.dart';
import '../services/update_checker.dart';
import '../state/app_controller.dart';
import '../widgets/chat_panel.dart';
import '../widgets/note_editor.dart';
import '../widgets/vault_browser.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _mobileTab = 2; // default chat on phone

  AppController get controller => widget.controller;

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
              child: Text(
                defaultTargetPlatform == TargetPlatform.android
                    ? 'Скачать'
                    : 'Скачать .exe',
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    final online = controller.activeRouteOnline;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return AppBar(
      title: const Text('SecondBrain'),
      actions: [
        Tooltip(
          message:
              'Ollama: ${controller.ollamaOnline ? "online" : "offline"} · '
              'Cloud ${controller.settings.cloudProvider.shortLabel}: '
              '${controller.cloudReachable ? "ok" : "n/a"}'
              '${controller.lastBackend != null ? " · last: ${controller.lastBackend!.label}" : ""}',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: online ? Colors.green : Colors.redAccent,
                ),
                if (!narrow) ...[
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      controller.activeRouteLabel,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Проверить LLM',
          icon: const Icon(Icons.wifi_tethering),
          onPressed: () => controller.checkBackends(),
        ),
        if (!narrow)
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
                builder: (_) => SettingsScreen(controller: controller),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _desktopBody(BuildContext context) {
    return Row(
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
    );
  }

  Widget _mobileBody() {
    switch (_mobileTab) {
      case 0:
        return VaultBrowser(controller: controller);
      case 1:
        return NoteEditor(controller: controller);
      default:
        return ChatPanel(controller: controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Compact shell for phones/narrow windows. Wide Android tablets keep
    // the desktop three-pane layout (tests also use a wide surface).
    final useMobile = MediaQuery.sizeOf(context).width < 900;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: _appBar(context),
          body: useMobile ? _mobileBody() : _desktopBody(context),
          bottomNavigationBar: useMobile
              ? NavigationBar(
                  selectedIndex: _mobileTab.clamp(0, 2),
                  onDestinationSelected: (i) => setState(() => _mobileTab = i),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.folder_outlined),
                      selectedIcon: Icon(Icons.folder),
                      label: 'Vault',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.edit_note_outlined),
                      selectedIcon: Icon(Icons.edit_note),
                      label: 'Заметка',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.chat_bubble_outline),
                      selectedIcon: Icon(Icons.chat_bubble),
                      label: 'Чат',
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}
