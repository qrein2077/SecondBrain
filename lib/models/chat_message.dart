enum ChatRole { user, assistant, system, error }

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    DateTime? createdAt,
    this.draftBundle,
  }) : createdAt = createdAt ?? DateTime.now();

  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final NoteDraftBundle? draftBundle;
}

class NoteDraft {
  const NoteDraft({
    required this.path,
    required this.content,
    required this.op,
  });

  /// Relative path inside the vault (posix-style separators preferred).
  final String path;

  /// Full markdown content to write on approve.
  final String content;

  /// `create` or `update`.
  final String op;

  factory NoteDraft.fromJson(Map<String, dynamic> json) {
    return NoteDraft(
      path: (json['path'] as String? ?? '').trim().replaceAll('\\', '/'),
      content: json['content'] as String? ?? '',
      op: (json['op'] as String? ?? 'create').toLowerCase(),
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
}
