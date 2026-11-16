import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/services/wiki_link.dart';
import 'package:secondbrain/services/update_checker.dart';

void main() {
  test('WikiLink resolve by basename and path', () {
    const files = ['Inbox/a.md', 'Science/physics.md', 'notes.md'];
    expect(WikiLink.resolve('physics', files), 'Science/physics.md');
    expect(WikiLink.resolve('Science/physics.md', files), 'Science/physics.md');
    expect(WikiLink.resolve('notes', files), 'notes.md');
    expect(WikiLink.resolve('missing', files), isNull);
    expect(WikiLink.targetOf('path|alias'), 'path');
    expect(WikiLink.displayOf('path|alias'), 'alias');
  });

  test('UpdateChecker version compare', () {
    expect(UpdateChecker.isNewer('1.0.1', '1.0.0'), isTrue);
    expect(UpdateChecker.isNewer('1.0.0', '1.0.0'), isFalse);
    expect(UpdateChecker.isNewer('0.9.9', '1.0.0'), isFalse);
  });
}
