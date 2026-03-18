import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../../domain/models/agent_handoff.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';
import '../../infrastructure/services/agent_memory_service.dart';

class ReviewerAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;
  final AgentMemoryService memoryService;
  final String? Function()? projectPathProvider;

  ReviewerAgent({
    required this.bus,
    required this.aiProvider,
    required this.memoryService,
    this.projectPathProvider,
  });

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
      final payload =
          AgentHandoff.unwrapData(event.payload) as Map<String, dynamic>;
      final codeLog = payload['codeLog'] ?? '';
      final originalTask = payload['originalTask'];
      final memoryContext = await memoryService.buildExecutionContext(
        task: '$originalTask\n$codeLog',
        projectPath: projectPathProvider?.call(),
        agentName: name,
      );

      final prompt =
          '''
You are an ELITE senior code reviewer. Analyze the following implementation logs for the task: $originalTask

$memoryContext

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
            targetAgent: 'PreviewAgent',
            type: AgentEventType.taskAssigned,
            payload: AgentHandoff(
              status: 'completed',
              reason: 'Review passed and preview can start.',
              artifacts: ['review_result'],
              evidence: ['ReviewerAgent returned LGTM.'],
              nextRecommendedAgent: 'PreviewAgent',
              data: {'command': 'start'},
            ).toJson(),
          ),
        );

        bus.publish(
          AgentEvent(
            sourceAgent: name,
            targetAgent: 'System',
            type: AgentEventType.taskCompleted,
            payload: AgentHandoff(
              status: 'completed',
              reason: 'Review passed. LGTM. Auto-starting dev server.',
              artifacts: ['review_result'],
              evidence: [review],
              nextRecommendedAgent: 'PreviewAgent',
            ).toJson(),
          ),
        );
      } else {
        bus.publish(
          AgentEvent(
            sourceAgent: name,
            targetAgent: 'SupervisorAgent',
            type: AgentEventType.taskAssigned,
            payload: AgentHandoff(
              status: 'failed',
              reason: 'Review failed and requires recovery routing.',
              artifacts: ['review_result'],
              evidence: [review],
              nextRecommendedAgent: 'SupervisorAgent',
              data: {
                'sourceAgent': name,
                'failure': 'Code review failed. Feedback:\\n$review',
                'retryCount': 1,
              },
            ).toJson(),
          ),
        );
      }
    } catch (e) {
      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskFailed,
          payload: AgentHandoff(
            status: 'failed',
            reason: 'Failed to complete review: $e',
            evidence: ['ReviewerAgent threw an exception.'],
            nextRecommendedAgent: 'SupervisorAgent',
          ).toJson(),
        ),
      );
    }
  }
}
