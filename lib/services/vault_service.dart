import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/chat_message.dart';

/// Local vault filesystem helpers. Writes only via atomic temp+rename.
class VaultService {
  VaultService({required this.vaultRoot});

  final String vaultRoot;

  Directory get rootDir => Directory(vaultRoot);

  bool get isConfigured => vaultRoot.trim().isNotEmpty;

  void ensureConfigured() {
    if (!isConfigured) {
      throw StateError('Путь к vault не задан. Откройте Настройки.');
    }
    if (!rootDir.existsSync()) {
      throw StateError('Папка vault не найдена: $vaultRoot');
    }
  }

  /// Absolute path for a vault-relative path. Rejects escapes outside vault.
  String resolveSafe(String relativePath) {
    ensureConfigured();
    final normalized = relativePath.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Пустой путь заметки');
    }
    if (normalized.startsWith('/') ||
        normalized.contains(':') ||
        normalized.split('/').any((s) => s == '..')) {
      throw ArgumentError('Небезопасный путь: $relativePath');
    }
    final abs = p.normalize(p.join(vaultRoot, normalized));
    final rootAbs = p.normalize(vaultRoot);
    final rootPrefix = rootAbs.endsWith(p.separator)
        ? rootAbs
        : '$rootAbs${p.separator}';
    if (abs != rootAbs && !abs.startsWith(rootPrefix)) {
      throw ArgumentError('Путь вне vault: $relativePath');
    }
    return abs;
  }

  /// Recursively list `.md` files relative to vault root.
  Future<List<String>> listMarkdownFiles() async {
    ensureConfigured();
    final files = <String>[];
    await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (!name.toLowerCase().endsWith('.md')) continue;
      // Skip hidden directories (e.g. .obsidian)
      final rel = p.relative(entity.path, from: vaultRoot);
      final parts = p.split(rel);
      if (parts.any((part) => part.startsWith('.'))) continue;
      files.add(rel.replaceAll('\\', '/'));
    }
    files.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return files;
  }

  Future<String> readNote(String relativePath) async {
    final abs = resolveSafe(relativePath);
    final file = File(abs);
    if (!await file.exists()) {
      throw FileSystemException('Файл не найден', abs);
    }
    return file.readAsString();
  }

  /// Manual save for human edits (explicit user action).
  Future<void> saveNote(String relativePath, String content) async {
    await _atomicWrite(relativePath, content);
  }

  /// Approve a multi-file draft as a batch:
  /// 1) validate all paths, 2) stage all temps, 3) rename each into place.
  /// If staging fails, no vault files are changed. If a rename fails mid-batch,
  /// earlier files may already be updated — error lists what succeeded.
  Future<List<String>> approveDrafts(NoteDraftBundle bundle) async {
    ensureConfigured();
    if (bundle.files.isEmpty) return const [];

    // Deduplicate by path (last wins) so one path isn't written twice.
    final byPath = <String, NoteDraft>{};
    for (final d in bundle.files) {
      byPath[d.path.replaceAll('\\', '/')] = d;
    }
    final drafts = byPath.values.toList();

    // Validate all paths first.
    final absPaths = <String, String>{};
    for (final d in drafts) {
      absPaths[d.path] = resolveSafe(d.path);
    }

    final staged = <_StagedWrite>[];
    try {
      for (final d in drafts) {
        final abs = absPaths[d.path]!;
        final target = File(abs);
        final dir = target.parent;
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final tmp = File(
          p.join(
            dir.path,
            '.${p.basename(abs)}.${DateTime.now().microsecondsSinceEpoch}.tmp',
          ),
        );
        await tmp.writeAsString(d.content, flush: true);
        staged.add(_StagedWrite(relativePath: d.path, tmp: tmp, target: target));
      }

      final written = <String>[];
      for (final s in staged) {
        await _commitStaged(s);
        written.add(s.relativePath);
      }
      return written;
    } catch (e) {
      // Clean up any temps that were not committed.
      for (final s in staged) {
        try {
          if (await s.tmp.exists()) await s.tmp.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> _commitStaged(_StagedWrite s) async {
    final abs = s.target.path;
    if (await s.target.exists()) {
      await s.tmp.rename(abs);
    } else {
      try {
        await s.tmp.rename(abs);
      } on FileSystemException {
        await s.tmp.copy(abs);
        await s.tmp.delete();
      }
    }
  }

  Future<void> _atomicWrite(String relativePath, String content) async {
    await approveDrafts(
      NoteDraftBundle(
        files: [
          NoteDraft(path: relativePath, content: content, op: 'update'),
        ],
      ),
    );
  }
}

class _StagedWrite {
  _StagedWrite({
    required this.relativePath,
    required this.tmp,
    required this.target,
  });

  final String relativePath;
  final File tmp;
  final File target;
}
