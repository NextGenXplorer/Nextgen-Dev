import 'package:dio/dio.dart';
import '../../domain/agent/agent_tool.dart';
import '../../application/agent/agentic_loop_service.dart';

/// Implementation of the AgentApiClient to communicate with OpenAI's REST API.
class OpenAIApiClient implements AgentApiClient {
  final Dio _dio;
  final String apiKey;
  final String model;

  OpenAIApiClient({
    required this.apiKey,
    this.model = 'gpt-4o',
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options.baseUrl = 'https://api.openai.com/v1';
    _dio.options.headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
  }

  @override
  Future<AgentMessage> getChatCompletion(List<AgentMessage> messages, List<AgentTool> tools) async {
    // 1. Map our generic AgentMessage list to OpenAI's required format
    final openAiMessages = messages.map((m) {
      final map = <String, dynamic>{
        'role': m.role,
        'content': m.content,
      };
      
      if (m.toolCallId != null) {
        map['tool_call_id'] = m.toolCallId;
      }
      if (m.toolCalls != null && m.toolCalls!.isNotEmpty) {
        map['tool_calls'] = m.toolCalls!.map((tc) => {
          'id': tc.id,
          'type': 'function',
          'function': {
            'name': tc.function.name,
            'arguments': tc.function.arguments, // Expected to be stringified JSON
          }
        }).toList();
        // OpenAI requires content to be present, even if null, when tool_calls are sent
        map['content'] = (m.content == null || m.content!.isEmpty) ? null : m.content;
      }
      return map;
    }).toList();

    // 2. Map our registered tools to OpenAI's Tool Calling Schema
    final openAiTools = tools.map((t) => {
      'type': 'function',
      'function': {
        'name': t.name,
        'description': t.description,
        'parameters': t.parameters,
      }
    }).toList();

    final payload = {
      'model': model,
      'messages': openAiMessages,
      if (openAiTools.isNotEmpty) 'tools': openAiTools,
      'temperature': 0.1, // Low temperature for deterministic tool execution
    };

    try {
      final response = await _dio.post('/chat/completions', data: payload);
      final choice = response.data['choices'][0]['message'];

      // 3. Parse the response back into our generic AgentMessage format
      final responseContent = choice['content'] ?? '';
      List<ToolCall>? parsedToolCalls;

      if (choice['tool_calls'] != null) {
        final List<dynamic> rawToolCalls = choice['tool_calls'];
        parsedToolCalls = rawToolCalls.map((tc) {
          return ToolCall(
            id: tc['id'],
            type: tc['type'],
            function: FunctionCall(
              name: tc['function']['name'],
              arguments: tc['function']['arguments'],
            ),
          );
        }).toList();
      }

      return AgentMessage(
        role: choice['role'],
        content: responseContent,
        toolCalls: parsedToolCalls,
      );

    } on DioException catch (e) {
      final errorMessage = e.response?.data['error']['message'] ?? e.message;
      throw Exception('OpenAI API Error: $errorMessage');
    } catch (e) {
      throw Exception('Failed to communicate with OpenAI: $e');
    }
  }
}
