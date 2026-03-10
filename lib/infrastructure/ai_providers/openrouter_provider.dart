import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';

class OpenRouterProvider implements AIProvider {
  final String apiKey;
  final String model;

  OpenRouterProvider({required this.apiKey, this.model = 'openai/gpt-4o-mini'});

  @override
  String get name => 'OpenRouter ($model)';

  @override
  Future<String> generate(List<ChatMessage> history) async {
    final response = await http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'HTTP-Referer': 'https://mobile_ai_ide.app',
        'X-Title': 'Mobile AI IDE',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': history.map((m) {
          if (m.images != null && m.images!.isNotEmpty) {
             return {
               'role': m.role == MessageRole.user ? 'user' : 'assistant',
               'content': [
                 {'type': 'text', 'text': m.content},
                 ...m.images!.map((bytes) => {
                   'type': 'image_url',
                   'image_url': {
                     'url': 'data:image/png;base64,${base64Encode(bytes)}'
                   }
                 }),
               ],
             };
          }
          return {
            'role': m.role == MessageRole.user ? 'user' : 'assistant',
            'content': m.content,
          };
        }).toList(),
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['choices'][0]['message']['content'];
    } else {
      throw Exception('OpenRouter API Error: ${response.body}');
    }
  }

  @override
  Stream<String> generateStream(List<ChatMessage> history) async* {
    final request = http.Request('POST', Uri.parse('https://openrouter.ai/api/v1/chat/completions'));
    request.headers.addAll({
      'HTTP-Referer': 'https://mobile_ai_ide.app',
      'X-Title': 'Mobile AI IDE',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    });

    request.body = jsonEncode({
      'model': model,
      'stream': true,
      'messages': history.map((m) => {
        'role': m.role == MessageRole.user ? 'user' : 'assistant',
        'content': m.content,
      }).toList(),
    });

    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception('OpenRouter Stream Error: $body');
    }

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      // Fix: split on actual newline character, not escaped \\n
      final lines = chunk.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('data: ') && trimmed != 'data: [DONE]') {
          try {
            final json = jsonDecode(trimmed.substring(6));
            final content = json['choices'][0]['delta']['content'];
            if (content != null) {
              yield content as String;
            }
          } catch (_) {
            // Ignore parse errors for incomplete chunks
          }
        }
      }
    }
  }
}
