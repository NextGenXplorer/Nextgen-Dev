import 'dart:typed_data';

enum MessageRole { user, model, system }

class ChatMessage {
  final MessageRole role;
  final String content;
  final List<Uint8List>? images;

  const ChatMessage({required this.role, required this.content, this.images});
}
