import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/models/app_settings.dart';

void main() {
  test('shipped defaults recognized for migration', () {
    expect(AppSettings.isShippedDefaultPrompt(''), isTrue);
    expect(
      AppSettings.isShippedDefaultPrompt(AppSettings.legacyDefaultSystemPromptV1),
      isTrue,
    );
    expect(
      AppSettings.isShippedDefaultPrompt(AppSettings.legacyDefaultSystemPromptV2),
      isTrue,
    );
    expect(
      AppSettings.isShippedDefaultPrompt(AppSettings.defaultSystemPrompt),
      isTrue,
    );
    expect(
      AppSettings.isShippedDefaultPrompt('Мой кастомный промпт'),
      isFalse,
    );
  });

  test('default prompt stresses multi-file vault scope', () {
    final p = AppSettings.defaultSystemPrompt;
    expect(p.contains('ВЕСЬ VAULT'), isTrue);
    expect(p.contains('НЕ привязан'), isTrue);
    expect(p.contains('PROPOSE_NOTES'), isTrue);
    expect(p.contains('wiki-links'), isTrue);
  });
}
