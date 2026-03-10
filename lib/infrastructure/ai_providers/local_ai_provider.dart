import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';

/// A provider for local LLM engines (Ollama, LM Studio, LocalAI) 
/// that expose an OpenAI-compatible API.
class LocalAIProvider implements AIProvider {
  final String baseUrl;
  final String model;
  final String? apiKey;
  final http.Client? client;

  LocalAIProvider({
    required this.baseUrl, 
    required this.model, 
    this.apiKey,
    this.client,
  });

  http.Client get _client => client ?? http.Client();

  @override
  String get name => 'Local ($model)';

  @override
  Future<String> generate(List<ChatMessage> history) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        if (apiKey != null && apiKey!.isNotEmpty) 'Authorization': 'Bearer $apiKey',
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
      throw Exception('Local AI Error (${response.statusCode}): ${response.body}');
    }
  }

  @override
  Stream<String> generateStream(List<ChatMessage> history) async* {
    final request = http.Request('POST', Uri.parse('$baseUrl/chat/completions'));
    request.headers.addAll({
      'Content-Type': 'application/json',
      if (apiKey != null && apiKey!.isNotEmpty) 'Authorization': 'Bearer $apiKey',
    });
    
    request.body = jsonEncode({
      'model': model,
      'stream': true,
      'messages': history.map((m) => {
        'role': m.role == MessageRole.user ? 'user' : 'assistant',
        'content': m.content,
      }).toList(),
    });

    final response = await _client.send(request);
    
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception('Local AI Stream Error (${response.statusCode}): $body');
    }

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      final lines = chunk.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (trimmed == 'data: [DONE]') break;
        
        if (trimmed.startsWith('data: ')) {
          try {
            final json = jsonDecode(trimmed.substring(6));
            final content = json['choices'][0]['delta']['content'];
            if (content != null) {
              yield content;
            }
          } catch (e) {
            // Ignore parse errors for incomplete chunks
          }
        }
      }
    }
  }
}
