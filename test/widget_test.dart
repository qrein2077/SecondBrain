import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:secondbrain/main.dart';
import 'package:secondbrain/state/app_controller.dart';

void main() {
  testWidgets('SecondBrain home shows title (desktop)', (tester) async {
    final controller = AppController();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(SecondBrainApp(controller: controller));
    await tester.pump();
    expect(find.text('SecondBrain'), findsOneWidget);
    expect(find.textContaining('Чат'), findsWidgets);
  });

  testWidgets('SecondBrain home shows on compact width', (tester) async {
    final controller = AppController();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(SecondBrainApp(controller: controller));
    await tester.pump();
    expect(find.text('SecondBrain'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
