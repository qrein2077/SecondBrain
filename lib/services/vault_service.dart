import '../models/chat_message.dart';
import 'vault_fs.dart';

/// Local vault helpers. Desktop uses dart:io; Android uses SAF tree URIs.
/// Writes are atomic where the backend allows; deletes prefer Recycle Bin
/// on Windows after explicit Approve (permanent delete on Android SAF).
class VaultService {
  VaultService({required this.vaultRoot}) : _fs = VaultFs.forRoot(vaultRoot);

  final String vaultRoot;
  final VaultFs _fs;

  bool get isConfigured => vaultRoot.trim().isNotEmpty;

  bool get isSaf => VaultFs.looksLikeSafUri(vaultRoot);

  String get rootLabel => _fs.rootLabel;

  void ensureConfigured() {
    if (!isConfigured) {
      throw StateError('Путь к vault не задан. Откройте Настройки.');
    }
  }

  /// Absolute path or SAF display key for a vault-relative path.
  String resolveSafe(String relativePath) {
    ensureConfigured();
    return _fs.resolveSafe(relativePath);
  }

  Future<List<String>> listMarkdownFiles() async {
    ensureConfigured();
    if (!await _fs.rootExists()) {
      throw StateError('Папка vault не найдена: $vaultRoot');
    }
    return _fs.listMarkdownFiles();
  }

  Future<String> readNote(String relativePath) async {
    ensureConfigured();
    return _fs.readNote(relativePath);
  }

  /// Manual save for human edits (explicit user action).
  Future<void> saveNote(String relativePath, String content) async {
    ensureConfigured();
    await _fs.writeNote(relativePath, content);
  }

  /// Approve a multi-file draft as a batch (create/update/delete).
  Future<List<String>> approveDrafts(NoteDraftBundle bundle) async {
    ensureConfigured();
    return applyDraftsOnFs(_fs, bundle);
  }
}
