import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/agent/agent_tool.dart';

/// Represents a message in the conversation history, adhering to standard LLM API formats.
class AgentMessage {
  final String role; // 'system', 'user', 'assistant', 'tool'
  final String? content;
  final String? toolCallId; // Used when role == 'tool'
  final List<ToolCall>? toolCalls; // Used when role == 'assistant'

  AgentMessage({
    required this.role,
    this.content,
    this.toolCallId,
    this.toolCalls,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'role': role,
      'content': content,
    };
    if (toolCallId != null) json['tool_call_id'] = toolCallId;
    if (toolCalls != null) {
      json['tool_calls'] = toolCalls!.map((t) => t.toJson()).toList();
    }
    return json;
  }
}

class ToolCall {
  final String id;
  final String type; // usually 'function'
  final FunctionCall function;

  ToolCall({
    required this.id,
    this.type = 'function',
    required this.function,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'function': function.toJson(),
  };
}

class FunctionCall {
  final String name;
  final String arguments; // JSON string of arguments

  FunctionCall({required this.name, required this.arguments});

  Map<String, dynamic> toJson() => {
    'name': name,
    'arguments': arguments,
  };
}

/// The state of the Agentic Loop
class AgentState {
  final List<AgentMessage> messages;
  final bool isGenerating;
  final String? currentAction; // E.g., 'Writing file main.dart'
  final String? error;

  AgentState({
    required this.messages,
    this.isGenerating = false,
    this.currentAction,
    this.error,
  });

  AgentState copyWith({
    List<AgentMessage>? messages,
    bool? isGenerating,
    String? currentAction,
    String? error,
  }) {
    return AgentState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      currentAction: currentAction, // Intentionally nullable
      error: error,
    );
  }
}

/// Abstract API Client that can be implemented for OpenAI, Anthropic, or Gemini.
abstract class AgentApiClient {
  Future<AgentMessage> getChatCompletion(List<AgentMessage> messages, List<AgentTool> tools);
}

/// The core Loop Service that orchestrates the ReAct loop.
class AgenticLoopNotifier extends StateNotifier<AgentState> {
  final AgentApiClient apiClient;
  final List<AgentTool> registeredTools;
  final int maxIterations = 15; // Safeguard to prevent infinite loops

  AgenticLoopNotifier({
    required this.apiClient,
    required this.registeredTools,
  }) : super(AgentState(messages: []));

  /// Initializes the conversation with the System Prompt, registering the persona.
  void init(String systemPrompt) {
    state = state.copyWith(
      messages: [AgentMessage(role: 'system', content: systemPrompt)],
    );
  }

  /// Sends a user prompt and begins the autonomous loop.
  Future<void> submitPrompt(String prompt) async {
    final updatedMessages = List<AgentMessage>.from(state.messages)
      ..add(AgentMessage(role: 'user', content: prompt));
    
    state = state.copyWith(messages: updatedMessages, isGenerating: true, error: null);

    int iterations = 0;

    try {
      while (iterations < maxIterations) {
        iterations++;
        
        // 1. Ask the LLM
        state = state.copyWith(currentAction: 'Thinking...');
        final responseMessage = await apiClient.getChatCompletion(state.messages, registeredTools);
        
        // Append LLM response to history
        final newMessages = List<AgentMessage>.from(state.messages)..add(responseMessage);
        state = state.copyWith(messages: newMessages);

        // 2. Check if the LLM wants to use tools
        if (responseMessage.toolCalls != null && responseMessage.toolCalls!.isNotEmpty) {
          // LLM wants to perform actions. We must loop after executing them.
          for (final toolCall in responseMessage.toolCalls!) {
            state = state.copyWith(currentAction: 'Executing ${toolCall.function.name}...');
            
            final tool = registeredTools.firstWhere(
              (t) => t.name == toolCall.function.name,
              orElse: () => throw Exception('Tool ${toolCall.function.name} not found'),
            );

            // Execute the specific tool
            final args = jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
            final observation = await tool.execute(args);

            // Append the observation back to the chat history so the LLM knows what happened
            newMessages.add(
              AgentMessage(
                role: 'tool',
                content: observation,
                toolCallId: toolCall.id,
              ),
            );
          }
          state = state.copyWith(messages: newMessages);
          // Loop continues... it will ask the LLM again with the new observations.
        } else {
          // LLM provided a plain text response and didn't call any tools. Task is complete.
          break;
        }
      }

      if (iterations >= maxIterations) {
        throw Exception('Agent loop terminated after $maxIterations iterations to prevent an infinite loop.');
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isGenerating: false, currentAction: null);
    }
  }
}

final agenticLoopProvider = StateNotifierProvider<AgenticLoopNotifier, AgentState>((ref) {
  throw UnimplementedError('Provide the API client and tools when initializing');
});
