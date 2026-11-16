import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:saf/saf.dart';

import '../models/chat_message.dart';

/// Platform filesystem backend for an Obsidian vault.
abstract class VaultFs {
  String get rootLabel;

  Future<bool> rootExists();

  /// Absolute or URI path for display / resolve checks.
  String resolveSafe(String relativePath);

  Future<List<String>> listMarkdownFiles();

  Future<String> readNote(String relativePath);

  Future<void> writeNote(String relativePath, String content);

  Future<void> deleteNote(String relativePath);

  static VaultFs forRoot(String vaultRoot) {
    final root = vaultRoot.trim();
    if (root.startsWith('content://') ||
        root.contains('/tree/') && root.startsWith('content:')) {
      return SafVaultFs(treeUri: root);
    }
    // SAF pickers sometimes return encoded tree URIs without content:// prefix
    // in older builds — treat explicit tree:// as SAF too.
    if (root.startsWith('tree:') || root.contains('com.android.externalstorage')) {
      final uri = root.startsWith('content://') ? root : 'content://$root';
      return SafVaultFs(treeUri: uri);
    }
    return IoVaultFs(vaultRoot: root);
  }

  static bool looksLikeSafUri(String path) {
    final t = path.trim();
    return t.startsWith('content://') ||
        t.contains('com.android.externalstorage');
  }
}

class IoVaultFs implements VaultFs {
  IoVaultFs({required this.vaultRoot});

  final String vaultRoot;

  Directory get rootDir => Directory(vaultRoot);

  @override
  String get rootLabel => vaultRoot;

  @override
  Future<bool> rootExists() async => rootDir.existsSync();

  @override
  String resolveSafe(String relativePath) {
    if (!rootDir.existsSync()) {
      throw StateError('Папка vault не найдена: $vaultRoot');
    }
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

  @override
  Future<List<String>> listMarkdownFiles() async {
    final files = <String>[];
    await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (!name.toLowerCase().endsWith('.md')) continue;
      final rel = p.relative(entity.path, from: vaultRoot);
      final parts = p.split(rel);
      if (parts.any((part) => part.startsWith('.'))) continue;
      files.add(rel.replaceAll('\\', '/'));
    }
    files.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return files;
  }

  @override
  Future<String> readNote(String relativePath) async {
    final abs = resolveSafe(relativePath);
    final file = File(abs);
    if (!await file.exists()) {
      throw FileSystemException('Файл не найден', abs);
    }
    return file.readAsString();
  }

  @override
  Future<void> writeNote(String relativePath, String content) async {
    final abs = resolveSafe(relativePath);
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
    await tmp.writeAsString(content, flush: true);
    if (await target.exists()) {
      await tmp.rename(abs);
    } else {
      try {
        await tmp.rename(abs);
      } on FileSystemException {
        await tmp.copy(abs);
        await tmp.delete();
      }
    }
  }

  @override
  Future<void> deleteNote(String relativePath) async {
    final abs = resolveSafe(relativePath);
    final file = File(abs);
    if (!await file.exists()) return;
    if (!kIsWeb && Platform.isWindows) {
      final recycled = await _sendToRecycleBin(abs);
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
}

/// Android SAF tree-URI vault (persistable DocumentTree grant).
class SafVaultFs implements VaultFs {
  SafVaultFs({required this.treeUri}) : _saf = Saf();

  final String treeUri;
  final Saf _saf;

  @override
  String get rootLabel => treeUri;

  void _assertSafeRel(String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) throw ArgumentError('Пустой путь заметки');
    if (normalized.startsWith('/') ||
        normalized.contains(':') ||
        normalized.split('/').any((s) => s == '..' || s.isEmpty)) {
      throw ArgumentError('Небезопасный путь: $relativePath');
    }
  }

  List<String> _segments(String relativePath) {
    _assertSafeRel(relativePath);
    return relativePath.replaceAll('\\', '/').split('/')
      ..removeWhere((s) => s.isEmpty);
  }

  @override
  String resolveSafe(String relativePath) {
    _assertSafeRel(relativePath);
    return '$treeUri :: ${relativePath.replaceAll('\\', '/')}';
  }

  @override
  Future<bool> rootExists() async {
    try {
      return await _saf.exists(treeUri);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> listMarkdownFiles() async {
    final files = <String>[];
    await for (final entry in _saf.walk(treeUri)) {
      final rel = entry.relativePath.replaceAll('\\', '/');
      final parts = rel.split('/');
      if (parts.any((part) => part.startsWith('.'))) continue;
      final name = parts.isEmpty ? '' : parts.last;
      if (!name.toLowerCase().endsWith('.md')) continue;
      if (entry.file.isDir) continue;
      files.add(rel);
    }
    files.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return files;
  }

  @override
  Future<String> readNote(String relativePath) async {
    final segs = _segments(relativePath);
    final doc = await _saf.child(treeUri, segs);
    if (doc == null) {
      throw StateError('Файл не найден (SAF): $relativePath');
    }
    final bytes = await _saf.readFileBytes(doc.uri);
    return utf8.decode(bytes);
  }

  @override
  Future<void> writeNote(String relativePath, String content) async {
    final segs = _segments(relativePath);
    final name = segs.last;
    final parentSegs = segs.sublist(0, segs.length - 1);
    final parent = parentSegs.isEmpty
        ? treeUri
        : (await _saf.mkdirp(treeUri, parentSegs)).uri;
    final data = Uint8List.fromList(utf8.encode(content));
    await _saf.writeFileBytes(
      parent,
      name,
      'text/markdown',
      data,
      overwrite: true,
    );
  }

  @override
  Future<void> deleteNote(String relativePath) async {
    final segs = _segments(relativePath);
    final doc = await _saf.child(treeUri, segs);
    if (doc == null) return; // idempotent
    await _saf.delete(doc.uri);
  }
}

/// Helper used by [VaultService.approveDrafts] for batch apply.
Future<List<String>> applyDraftsOnFs(
  VaultFs fs,
  NoteDraftBundle bundle,
) async {
  if (bundle.files.isEmpty) return const [];
  final byPath = <String, NoteDraft>{};
  for (final d in bundle.files) {
    byPath[d.path.replaceAll('\\', '/')] = d;
  }
  final drafts = byPath.values.toList();
  final applied = <String>[];
  try {
    // Validate paths first.
    for (final d in drafts) {
      fs.resolveSafe(d.path);
    }
    for (final d in drafts.where((d) => !d.isDelete)) {
      await fs.writeNote(d.path, d.content);
      applied.add(d.path);
    }
    for (final d in drafts.where((d) => d.isDelete)) {
      await fs.deleteNote(d.path);
      applied.add('удалён: ${d.path}');
    }
    return applied;
  } catch (e) {
    if (applied.isNotEmpty) {
      throw StateError(
        'Пакет применён частично (${applied.join(', ')}). Ошибка: $e',
      );
    }
    rethrow;
  }
}
