import 'chat_message.dart';

/// One persisted chat thread (messages + metadata).
class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : messages = messages ?? <ChatMessage>[],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  DateTime updatedAt;

  factory ChatSession.newSession({String? title}) {
    final now = DateTime.now();
    final id = 's_${now.microsecondsSinceEpoch}';
    return ChatSession(
      id: id,
      title: title ?? 'Чат ${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}',
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final rawMsgs = json['messages'];
    final msgs = <ChatMessage>[];
    if (rawMsgs is List) {
      for (final item in rawMsgs) {
        if (item is Map<String, dynamic>) {
          msgs.add(ChatMessage.fromJson(item));
        } else if (item is Map) {
          msgs.add(ChatMessage.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return ChatSession(
      id: json['id'] as String? ?? 's_unknown',
      title: json['title'] as String? ?? 'Чат',
      messages: msgs,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
