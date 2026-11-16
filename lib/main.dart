import 'package:material_ui/material_ui.dart';

import 'screens/home_screen.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  await controller.init();
  runApp(SecondBrainApp(controller: controller));
}

class SecondBrainApp extends StatelessWidget {
  const SecondBrainApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecondBrain',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F5D50),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(controller: controller),
    );
  }
}
