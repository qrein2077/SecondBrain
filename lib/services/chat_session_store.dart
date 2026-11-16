import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/chat_session.dart';

/// Persists chat sessions under application support `chat_sessions/`.
class ChatSessionStore {
  Directory? _dir;

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'chat_sessions'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  File _fileFor(String id) {
    final safe = id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return File(p.join(_dir!.path, '$safe.json'));
  }

  Future<List<ChatSession>> loadAll() async {
    final dir = await _ensureDir();
    final sessions = <ChatSession>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      if (p.basename(entity.path) == 'index.json') continue;
      try {
        final text = await entity.readAsString();
        final map = jsonDecode(text);
        if (map is Map<String, dynamic>) {
          sessions.add(ChatSession.fromJson(map));
        } else if (map is Map) {
          sessions.add(ChatSession.fromJson(Map<String, dynamic>.from(map)));
        }
      } catch (_) {}
    }
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }

  Future<void> save(ChatSession session) async {
    await _ensureDir();
    session.updatedAt = DateTime.now();
    final file = _fileFor(session.id);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(session.toJson()),
      flush: true,
    );
  }

  Future<void> delete(String id) async {
    await _ensureDir();
    final file = _fileFor(id);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String?> loadActiveId() async {
    final dir = await _ensureDir();
    final index = File(p.join(dir.path, 'index.json'));
    if (!await index.exists()) return null;
    try {
      final map = jsonDecode(await index.readAsString());
      if (map is Map && map['activeId'] is String) {
        return map['activeId'] as String;
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveActiveId(String id) async {
    final dir = await _ensureDir();
    final index = File(p.join(dir.path, 'index.json'));
    await index.writeAsString(
      jsonEncode({'activeId': id}),
      flush: true,
    );
  }
}
