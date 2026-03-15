import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';

class GroqProvider implements AIProvider {
  final String apiKey;
  final String model;

  GroqProvider({required this.apiKey, this.model = 'llama3-70b-8192'});

  @override
  String get name => 'Groq ($model)';

  @override
  Future<String> generate(List<ChatMessage> history) async {
    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': history
            .map(
              (m) => {
                'role': m.role == MessageRole.user ? 'user' : 'assistant',
                'content': m.content,
              },
            )
            .toList(),
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['choices'][0]['message']['content'];
    } else {
      throw Exception('Groq API Error: ${response.body}');
    }
  }

  @override
  Stream<String> generateStream(List<ChatMessage> history) async* {
    final request = http.Request(
      'POST',
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    });

    request.body = jsonEncode({
      'model': model,
      'stream': true,
      'messages': history
          .map(
            (m) => {
              'role': m.role == MessageRole.user ? 'user' : 'assistant',
              'content': m.content,
            },
          )
          .toList(),
    });

    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception('Groq Stream Error: $body');
    }

    await for (final chunk in response.stream.transform(utf8.decoder)) {
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
