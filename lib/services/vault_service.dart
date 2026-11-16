import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/chat_message.dart';

/// Local vault filesystem helpers. Writes via atomic temp+rename;
/// deletes prefer Recycle Bin on Windows after explicit Approve.
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

  /// Approve a multi-file draft as a batch (create/update/delete).
  ///
  /// Order (fail-safe):
  /// 1) validate all paths,
  /// 2) stage all create/update temps,
  /// 3) commit renames,
  /// 4) delete paths (Recycle Bin on Windows when possible).
  ///
  /// If staging/validation fails, vault is untouched (no deletes yet).
  /// Mid-batch commit/delete failures may leave earlier steps applied —
  /// returned list + error message name what succeeded.
  Future<List<String>> approveDrafts(NoteDraftBundle bundle) async {
    ensureConfigured();
    if (bundle.files.isEmpty) return const [];

    // Deduplicate by path (last wins) so one path isn't applied twice.
    final byPath = <String, NoteDraft>{};
    for (final d in bundle.files) {
      byPath[d.path.replaceAll('\\', '/')] = d;
    }
    final drafts = byPath.values.toList();
    final writes = drafts.where((d) => !d.isDelete).toList();
    final deletes = drafts.where((d) => d.isDelete).toList();

    // Validate all paths first (writes + deletes) before any mutation.
    final absPaths = <String, String>{};
    for (final d in drafts) {
      absPaths[d.path] = resolveSafe(d.path);
    }

    final staged = <_StagedWrite>[];
    final applied = <String>[];
    try {
      for (final d in writes) {
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

      for (final s in staged) {
        await _commitStaged(s);
        applied.add(s.relativePath);
      }

      for (final d in deletes) {
        final abs = absPaths[d.path]!;
        await _deleteVaultFile(abs);
        applied.add('удалён: ${d.path}');
      }

      return applied;
    } catch (e) {
      // Clean up any temps that were not committed.
      for (final s in staged) {
        try {
          if (await s.tmp.exists()) await s.tmp.delete();
        } catch (_) {}
      }
      if (applied.isNotEmpty) {
        throw StateError(
          'Пакет применён частично (${applied.join(', ')}). Ошибка: $e',
        );
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

  /// Prefer Windows Recycle Bin; fall back to permanent delete.
  Future<void> _deleteVaultFile(String absPath) async {
    final file = File(absPath);
    if (!await file.exists()) {
      // Missing file: treat as already deleted (idempotent).
      return;
    }
    if (Platform.isWindows) {
      final recycled = await _sendToRecycleBin(absPath);
      if (recycled) return;
    }
    await file.delete();
  }

  Future<bool> _sendToRecycleBin(String absPath) async {
    try {
      final escaped = absPath.replaceAll("'", "''");
      final script =
          "Add-Type -AssemblyName Microsoft.VisualBasic; "
          "[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile("
          "'$escaped', 'OnlyErrorDialogs', 'SendToRecycleBin')";
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', script],
        runInShell: false,
      );
      return result.exitCode == 0 && !await File(absPath).exists();
    } catch (_) {
      return false;
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
