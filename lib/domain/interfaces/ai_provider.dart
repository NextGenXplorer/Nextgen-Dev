import '../models/chat_message.dart';

abstract class AIProvider {
  String get name;

  /// Sends a complete history and returns a stream of the response
  Stream<String> generateStream(List<ChatMessage> history);

  /// Sends a complete history and returns a single future response
  Future<String> generate(List<ChatMessage> history);
}
