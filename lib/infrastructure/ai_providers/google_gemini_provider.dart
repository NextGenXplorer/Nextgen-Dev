import 'package:google_generative_ai/google_generative_ai.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart' as app_models;

class GoogleGeminiProvider implements AIProvider {
  final String apiKey;
  final GenerativeModel _model;

  GoogleGeminiProvider({required this.apiKey, String modelName = 'gemini-2.5-flash'})
      : _model = GenerativeModel(model: modelName, apiKey: apiKey);

  @override
  String get name => 'Google Gemini';

  @override
  Future<String> generate(List<app_models.ChatMessage> history) async {
    final contents = _mapHistory(history);
    final response = await _model.generateContent(contents);
    return response.text ?? '';
  }

  @override
  Stream<String> generateStream(List<app_models.ChatMessage> history) {
    final contents = _mapHistory(history);
    return _model.generateContentStream(contents).map((response) => response.text ?? '');
  }

  List<Content> _mapHistory(List<app_models.ChatMessage> history) {
    return history.where((msg) => msg.role != app_models.MessageRole.system).map((msg) {
      final role = msg.role == app_models.MessageRole.user ? 'user' : 'model';
      return Content(role, [TextPart(msg.content)]);
    }).toList();
  }
}
