enum ChatRole { user, assistant, system, error }

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    DateTime? createdAt,
    this.draftBundle,
    this.sources = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final NoteDraftBundle? draftBundle;

  /// Vault-relative note paths used for RAG-lite grounding (assistant turns).
  final List<String> sources;

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'sources': sources,
        if (draftBundle != null)
          'draftBundle': {
            'files': draftBundle!.files.map((f) => f.toJson()).toList(),
          },
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final roleName = json['role'] as String? ?? 'system';
    final role = ChatRole.values.firstWhere(
      (r) => r.name == roleName,
      orElse: () => ChatRole.system,
    );
    NoteDraftBundle? draft;
    final rawDraft = json['draftBundle'];
    if (rawDraft is Map) {
      final filesRaw = rawDraft['files'];
      final files = <NoteDraft>[];
      if (filesRaw is List) {
        for (final item in filesRaw) {
          if (item is Map<String, dynamic>) {
            files.add(NoteDraft.fromJson(item));
          } else if (item is Map) {
            files.add(NoteDraft.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
      if (files.isNotEmpty) draft = NoteDraftBundle(files: files);
    }
    final sourcesRaw = json['sources'];
    final sources = <String>[];
    if (sourcesRaw is List) {
      for (final s in sourcesRaw) {
        if (s is String && s.isNotEmpty) sources.add(s);
      }
    }
    return ChatMessage(
      role: role,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      draftBundle: draft,
      sources: sources,
    );
  }
}

class NoteDraft {
  const NoteDraft({
    required this.path,
    required this.content,
    required this.op,
  });

  /// Relative path inside the vault (posix-style separators preferred).
  final String path;

  /// Full markdown content to write on approve (empty for delete).
  final String content;

  /// `create`, `update`, or `delete`.
  final String op;

  bool get isDelete => op == 'delete';
  bool get isUpdate => op == 'update';
  bool get isCreate => op == 'create' || (op != 'update' && op != 'delete');

  String get opLabelRu {
    switch (op) {
      case 'delete':
        return 'удалить';
      case 'update':
        return 'обновить';
      default:
        return 'создать';
    }
  }

  factory NoteDraft.fromJson(Map<String, dynamic> json) {
    var op = (json['op'] as String? ?? 'create').toLowerCase().trim();
    if (op != 'create' && op != 'update' && op != 'delete') {
      op = 'create';
    }
    return NoteDraft(
      path: (json['path'] as String? ?? '').trim().replaceAll('\\', '/'),
      content: json['content'] as String? ?? '',
      op: op,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'content': content,
        'op': op,
      };
}

class NoteDraftBundle {
  const NoteDraftBundle({required this.files});

  final List<NoteDraft> files;

  bool get isEmpty => files.isEmpty;
  bool get isNotEmpty => files.isNotEmpty;

  int get deleteCount => files.where((f) => f.isDelete).length;
  int get writeCount => files.length - deleteCount;
  bool get hasDeletes => deleteCount > 0;
}
