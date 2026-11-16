import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/services/agent_parser.dart';

void main() {
  test('parses propose notes block', () {
    const raw = '''
Вот структура.

<<<PROPOSE_NOTES>>>
[
  {"path": "Ideas/foo.md", "op": "create", "content": "# Foo\\n\\nSee [[bar]]"},
  {"path": "Ideas/bar.md", "op": "create", "content": "# Bar"}
]
<<<END_PROPOSE_NOTES>>>
''';
    final parsed = AgentParser.parse(raw);
    expect(parsed.displayText.contains('Вот структура'), isTrue);
    expect(parsed.draft, isNotNull);
    expect(parsed.draft!.files, hasLength(2));
    expect(parsed.draft!.files.first.path, 'Ideas/foo.md');
    expect(parsed.draft!.files.first.content.contains('[[bar]]'), isTrue);
  });

  test('no block returns plain text', () {
    final parsed = AgentParser.parse('Просто ответ');
    expect(parsed.displayText, 'Просто ответ');
    expect(parsed.draft, isNull);
  });
}
