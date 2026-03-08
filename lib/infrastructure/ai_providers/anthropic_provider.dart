import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';

class AnthropicProvider implements AIProvider {
  final String apiKey;
  final String model;

  AnthropicProvider({required this.apiKey, this.model = 'claude-3-5-haiku-20241022'});

  @override
  String get name => 'Anthropic ($model)';

  @override
  Future<String> generate(List<ChatMessage> history) async {
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': 4096,
        'messages': history.map((m) => {
          'role': m.role == MessageRole.user ? 'user' : 'assistant',
          'content': m.content,
        }).toList(),
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['content'][0]['text'];
    } else {
      throw Exception('Anthropic API Error: ${response.body}');
    }
  }

  @override
  Stream<String> generateStream(List<ChatMessage> history) async* {
    final request = http.Request('POST', Uri.parse('https://api.anthropic.com/v1/messages'));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    });

    request.body = jsonEncode({
      'model': model,
      'max_tokens': 4096,
      'stream': true,
      'messages': history.map((m) => {
        'role': m.role == MessageRole.user ? 'user' : 'assistant',
        'content': m.content,
      }).toList(),
    });

    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception('Anthropic Stream Error: $body');
    }

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      final lines = chunk.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('data: ')) {
          try {
            final json = jsonDecode(trimmed.substring(6));
            if (json['type'] == 'content_block_delta') {
              final text = json['delta']['text'];
              if (text != null) yield text as String;
            }
          } catch (_) {
            // Ignore incomplete chunks
          }
        }
      }
    }
  }
}
