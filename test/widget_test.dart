import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/main.dart';
import 'package:secondbrain/state/app_controller.dart';

void main() {
  testWidgets('SecondBrain home shows title', (tester) async {
    final controller = AppController();
    // Desktop-like surface for the three-pane shell.
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(SecondBrainApp(controller: controller));
    expect(find.text('SecondBrain'), findsOneWidget);
    expect(find.text('Чат'), findsOneWidget);
  });
}
