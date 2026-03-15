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
  String get description =>
      'A senior code reviewer that analyzes diffs and provides feedback.';

  @override
  bool canHandle(AgentEvent event) {
    return event.targetAgent == name &&
        event.type == AgentEventType.taskAssigned;
  }

  @override
  Future<void> handleEvent(AgentEvent event) async {
    bus.publish(
      AgentEvent(
        sourceAgent: name,
        targetAgent: 'System',
        type: AgentEventType.message,
        payload: 'ReviewerAgent is analyzing the code...',
      ),
    );

    try {
      final payload = event.payload as Map<String, dynamic>;
      final codeLog = payload['codeLog'] ?? '';
      final originalTask = payload['originalTask'];

      final prompt =
          '''
You are an ELITE senior code reviewer. Analyze the following implementation logs for the task: $originalTask

Rules:
- Reject commits with obvious flaws, missing error handling, or generic UI implementations.
- You MUST look for explicit evidence in the log that the CoderAgent or DebuggerAgent ran a test or build command (like `flutter analyze` or `npm run build`) AND that it succeeded.
- If there is NO evidence of a successful test/build run, you MUST REJECT it.
- Provide specific feedback on what needs to be fixed.
- If the code is perfect AND tests/builds pass, output exclusively 'LGTM'.

Implementation Context:
$codeLog
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];
      final review = (await aiProvider.generate(history)).trim();

      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'User',
          type: AgentEventType.message,
          payload: 'Code Review Result:\\n$review',
        ),
      );

      if (review == 'LGTM') {
        bus.publish(
          AgentEvent(
            sourceAgent: name,
            targetAgent: 'User',
            type: AgentEventType.message,
            payload: 'Agent finished all tasks! You can now test it.',
          ),
        );

        bus.publish(
          AgentEvent(
            sourceAgent: name,
            targetAgent: 'ServeAgent',
            type: AgentEventType.taskAssigned,
            payload: 'start',
          ),
        );

        bus.publish(
          AgentEvent(
            sourceAgent: name,
            targetAgent: 'System',
            type: AgentEventType.taskCompleted,
            payload: 'Review passed. LGTM. Auto-starting dev server.',
          ),
        );
      } else {
        bus.publish(
          AgentEvent(
            sourceAgent: name,
            targetAgent: 'CoderAgent',
            type: AgentEventType.taskFailed,
            payload: 'Code review failed. Feedback:\\n$review',
          ),
        );
      }
    } catch (e) {
      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskFailed,
          payload: 'Failed to complete review: $e',
        ),
      );
    }
  }
}
