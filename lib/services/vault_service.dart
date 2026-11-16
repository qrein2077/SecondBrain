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

  /// Approve a multi-file draft bundle. Each file is written atomically.
  Future<List<String>> approveDrafts(NoteDraftBundle bundle) async {
    ensureConfigured();
    final written = <String>[];
    for (final draft in bundle.files) {
      await _atomicWrite(draft.path, draft.content);
      written.add(draft.path);
    }
    return written;
  }

  Future<void> _atomicWrite(String relativePath, String content) async {
    final abs = resolveSafe(relativePath);
    final target = File(abs);
    final dir = target.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final tmp = File(
      p.join(dir.path, '.${p.basename(abs)}.${DateTime.now().microsecondsSinceEpoch}.tmp'),
    );
    try {
      await tmp.writeAsString(content, flush: true);
      if (await target.exists()) {
        await tmp.rename(abs);
      } else {
        // On Windows, rename to non-existing path works; if not, copy+delete.
        try {
          await tmp.rename(abs);
        } on FileSystemException {
          await tmp.copy(abs);
          await tmp.delete();
        }
      }
    } catch (_) {
      if (await tmp.exists()) {
        await tmp.delete();
      }
      rethrow;
    }
  }
}
