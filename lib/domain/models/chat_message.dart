enum MessageRole { user, model, system }

class ChatMessage {
  final MessageRole role;
  final String content;

  const ChatMessage({
    required this.role,
    required this.content,
  });
}
