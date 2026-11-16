import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:secondbrain/services/vault_retriever.dart';
import 'package:secondbrain/services/vault_service.dart';

void main() {
  late Directory tmp;
  late VaultService vault;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('sb_retriever_');
    await File(p.join(tmp.path, 'physics.md')).writeAsString(
      '# Физика\n\nМеханика, кинематика, законы Ньютона.\n',
    );
    await File(p.join(tmp.path, 'cooking.md')).writeAsString(
      '# Кулинария\n\nРецепт борща и пирогов.\n',
    );
    await Directory(p.join(tmp.path, 'Science')).create();
    await File(p.join(tmp.path, 'Science', 'optics.md')).writeAsString(
      '# Оптика\n\nПреломление света, линзы, физика волны.\n',
    );
    vault = VaultService(vaultRoot: tmp.path);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('tokenize soft-stems физике → physics notes', () async {
    final files = await vault.listMarkdownFiles();
    final hits = await const VaultRetriever().retrieve(
      vault: vault,
      files: files,
      query: 'что я уже знаю по физике',
    );
    expect(hits, isNotEmpty);
    final paths = hits.map((h) => h.path).toList();
    expect(
      paths.any((p) => p.toLowerCase().contains('physics') || p.contains('optics')),
      isTrue,
    );
    expect(paths.any((p) => p.contains('cooking')), isFalse);
  });

  test('formatForPrompt forbids open-file instructions', () {
    final text = VaultRetriever.formatForPrompt(const [
      VaultHit(path: 'a.md', snippet: 'hello', score: 1),
    ]);
    expect(text, contains('Выдержки из vault'));
    expect(text, contains('открой файл'));
    expect(text, contains('`a.md`'));
  });

  test('tokenize returns empty for unrelated stopword-only query', () async {
    final files = await vault.listMarkdownFiles();
    final hits = await const VaultRetriever().retrieve(
      vault: vault,
      files: files,
      query: 'что и как',
    );
    expect(hits, isEmpty);
  });
}
