import 'chat_message.dart';

class Conversation {
  final String id;
  final String title;
  final String provider;
  final DateTime createdAt;
  final List<ChatMessage> messages;

  const Conversation({
    required this.id,
    required this.title,
    required this.provider,
    required this.createdAt,
    required this.messages,
  });

  Conversation copyWith({
    String? id,
    String? title,
    String? provider,
    DateTime? createdAt,
    List<ChatMessage>? messages,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      provider: provider ?? this.provider,
      createdAt: createdAt ?? this.createdAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'provider': provider,
    'createdAt': createdAt.toIso8601String(),
    'messages': messages
        .map((m) => {'role': m.role.name, 'content': m.content})
        .toList(),
  };

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String,
      provider: json['provider'] as String? ?? 'gemini',
      createdAt: DateTime.parse(json['createdAt'] as String),
      messages: (json['messages'] as List<dynamic>)
          .map(
            (m) => ChatMessage(
              role: MessageRole.values.firstWhere(
                (r) => r.name == m['role'],
                orElse: () => MessageRole.user,
              ),
              content: m['content'] as String,
            ),
          )
          .toList(),
    );
  }
}
