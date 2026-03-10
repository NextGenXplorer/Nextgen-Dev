import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';

class ReviewerAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;

  ReviewerAgent({required this.bus, required this.aiProvider});

  @override
  String get name => 'ReviewerAgent';

  @override
  String get description => 'A senior code reviewer that analyzes diffs and provides feedback.';

  @override
  bool canHandle(AgentEvent event) {
    return event.targetAgent == name && event.type == AgentEventType.taskAssigned;
  }

  @override
  Future<void> handleEvent(AgentEvent event) async {
    bus.publish(AgentEvent(
      sourceAgent: name,
      targetAgent: 'System',
      type: AgentEventType.message,
      payload: 'ReviewerAgent is analyzing the code...',
    ));

    try {
      final payload = event.payload as Map<String, dynamic>;
      final codeLog = payload['codeLog'] ?? '';
      final originalTask = payload['originalTask'];

      final prompt = '''
You are a senior code reviewer. Analyze the following implementation logs for the task: $originalTask

Rules:
- Reject commits with obvious flaws or missing error handling based on the log.
- Provide specific feedback.
- If approved, output exclusively 'LGTM'.

Implementation Context:
$codeLog
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];
      final review = (await aiProvider.generate(history)).trim();

      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'User',
        type: AgentEventType.message,
        payload: 'Code Review Result:\\n$review',
      ));

      if (review == 'LGTM') {
        bus.publish(AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskCompleted,
          payload: 'Review passed. LGTM.',
        ));
        
        // Example: Hand off to deployer automatically or wait for user action
        // For this sprint implementation, we'll just announce completion.
      } else {
        bus.publish(AgentEvent(
          sourceAgent: name,
          targetAgent: 'CoderAgent',
          type: AgentEventType.taskFailed,
          payload: 'Code review failed. Feedback:\\n$review',
        ));
      }

    } catch (e) {
      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'System',
        type: AgentEventType.taskFailed,
        payload: 'Failed to complete review: $e',
      ));
    }
  }
}
