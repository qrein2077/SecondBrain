import 'package:material_ui/material_ui.dart';

import '../state/app_controller.dart';
import '../widgets/chat_panel.dart';
import '../widgets/note_editor.dart';
import '../widgets/vault_browser.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('SecondBrain'),
            actions: [
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
