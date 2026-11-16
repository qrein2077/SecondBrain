import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/models/app_settings.dart';
import 'package:secondbrain/services/agent_parser.dart';

void main() {
  const sample = '''
План готов.
<<<PROPOSE_NOTES>>>
[{"path":"a.md","op":"create","content":"# A"}]
<<<END_PROPOSE_NOTES>>>
''';

  test('parse allows drafts by default', () {
    final r = AgentParser.parse(sample);
    expect(r.draft, isNotNull);
    expect(r.draft!.files, hasLength(1));
    expect(r.displayText, contains('План готов'));
    expect(r.displayText, isNot(contains('PROPOSE_NOTES')));
  });

  test('parse strips drafts in Q&A-only', () {
    final r = AgentParser.parse(sample, allowDrafts: false);
    expect(r.draft, isNull);
    expect(r.displayText, contains('План готов'));
    expect(r.displayText, isNot(contains('PROPOSE_NOTES')));
  });

  test('shipped prompt migration includes delete-capable v4', () {
    expect(AppSettings.currentPromptVersion, 4);
    expect(
      AppSettings.isShippedDefaultPrompt(AppSettings.legacyDefaultSystemPromptV2),
      isTrue,
    );
    expect(
      AppSettings.isShippedDefaultPrompt(AppSettings.legacyDefaultSystemPromptV3),
      isTrue,
    );
    expect(
      AppSettings.isShippedDefaultPrompt(AppSettings.defaultSystemPrompt),
      isTrue,
    );
    expect(
      AppSettings.defaultSystemPrompt,
      contains('УТОЧНЯЮЩИЕ ВОПРОСЫ'),
    );
    expect(AppSettings.defaultSystemPrompt, contains('"delete"'));
    expect(AppSettings.qaOnlyAddonPrompt, contains('ТОЛЬКО ОТВЕТЫ'));
    expect(AppSettings.qaOnlyAddonPrompt, contains('delete'));
  });

  test('qaOnly defaults false', () {
    expect(const AppSettings().qaOnly, isFalse);
  });

  test('parse delete op', () {
    const raw = '''
<<<PROPOSE_NOTES>>>
[{"path":"old.md","op":"delete","content":""}]
<<<END_PROPOSE_NOTES>>>
''';
    final r = AgentParser.parse(raw);
    expect(r.draft, isNotNull);
    expect(r.draft!.files.single.isDelete, isTrue);
    expect(r.draft!.hasDeletes, isTrue);
  });
}
