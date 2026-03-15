import 'dart:async';
import '../../../domain/agent/agent_tool.dart';

/// Service interface representing the UI stream.
/// This would be implemented by a Riverpod Notifier providing a Stream
/// or a callback that displays a prompt dialog to the user in the UI.
abstract class UserInteractionService {
  Future<String> askUser(String prompt);
}

class InteractiveAskUserTool implements AgentTool {
  final UserInteractionService interactionService;

  InteractiveAskUserTool({required this.interactionService});

  @override
  String get name => 'ask_user';

  @override
  String get description => 
      'Use this tool when you are stuck, need clarification, or are about '
      'to perform a highly destructive action and need explicit user approval. '
      'It pauses the agentic loop and waits for the user\'s text response.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'question': {
        'type': 'string',
        'description': 'The clear, concise question to ask the user.',
      }
    },
    'required': ['question'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final question = arguments['question'] as String;
    
    try {
      // This will pause the AgenticLoopNotifier's execution loop 
      // awaiting the user's manual input from the UI layer.
      final userResponse = await interactionService.askUser(question);
      return 'User responded with: "$userResponse"';
    } catch (e) {
      return 'Action failed or cancelled by user: $e';
    }
  }
}
