import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:secondbrain/models/chat_message.dart';
import 'package:secondbrain/services/vault_service.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('secondbrain_vault_');
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  test('lists md files and skips hidden dirs', () async {
    await File(p.join(tmp.path, 'a.md')).writeAsString('# A');
    await Directory(p.join(tmp.path, 'sub')).create();
    await File(p.join(tmp.path, 'sub', 'b.md')).writeAsString('# B');
    await Directory(p.join(tmp.path, '.obsidian')).create();
    await File(p.join(tmp.path, '.obsidian', 'cfg.md')).writeAsString('x');

    final vault = VaultService(vaultRoot: tmp.path);
    final files = await vault.listMarkdownFiles();
    expect(files, containsAll(['a.md', 'sub/b.md']));
    expect(files.any((f) => f.contains('.obsidian')), isFalse);
  });

  test('rejects path escape', () {
    final vault = VaultService(vaultRoot: tmp.path);
    expect(() => vault.resolveSafe('../outside.md'), throwsArgumentError);
  });

  test('atomic approve writes multi-file batch', () async {
    final vault = VaultService(vaultRoot: tmp.path);
    final written = await vault.approveDrafts(
      const NoteDraftBundle(
        files: [
          NoteDraft(
            path: 'Inbox/hello.md',
            op: 'create',
            content: '# Hello\n\n[[world]]',
          ),
          NoteDraft(
            path: 'Inbox/world.md',
            op: 'create',
            content: '# World\n\n[[hello]]',
          ),
          NoteDraft(
            path: 'Topics/index.md',
            op: 'create',
            content: '# Index\n\n[[hello]] [[world]]',
          ),
        ],
      ),
    );
    expect(written, hasLength(3));
    final hello =
        await File(p.join(tmp.path, 'Inbox', 'hello.md')).readAsString();
    expect(hello.contains('[[world]]'), isTrue);
    expect(
      await File(p.join(tmp.path, 'Topics', 'index.md')).exists(),
      isTrue,
    );
  });

  test('staging failure leaves vault untouched', () async {
    final vault = VaultService(vaultRoot: tmp.path);
    expect(
      () => vault.approveDrafts(
        const NoteDraftBundle(
          files: [
            NoteDraft(path: 'ok.md', op: 'create', content: '# ok'),
            NoteDraft(path: '../escape.md', op: 'create', content: 'bad'),
          ],
        ),
      ),
      throwsArgumentError,
    );
    expect(await File(p.join(tmp.path, 'ok.md')).exists(), isFalse);
  });
}
