import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../../domain/models/agent_handoff.dart';
import '../../domain/models/agent_step.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';
import '../../infrastructure/agent/agent_service.dart';
import '../../infrastructure/services/agent_memory_service.dart';
import '../../infrastructure/storage/workspace_manager.dart';

class TestingAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;
  final WorkspaceManager workspaceManager;
  final AgentMemoryService memoryService;
  final String? Function()? projectPathProvider;

  TestingAgent({
    required this.bus,
    required this.aiProvider,
    required this.workspaceManager,
    required this.memoryService,
    this.projectPathProvider,
  });

  @override
  String get name => 'TestingAgent';

  @override
  String get description =>
      'An automated testing agent that runs terminal commands to verify code quality.';

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
        targetAgent: 'User',
        type: AgentEventType.message,
        payload: '🧪 TestingAgent is verifying implementation...',
      ),
    );

    try {
      final payload =
          AgentHandoff.unwrapData(event.payload) as Map<String, dynamic>;
      final codeLog = payload['codeLog'] ?? '';
      final originalTask = payload['originalTask'];

      final prompt =
          '''
You are an ELITE TESTING AGENT. Your job is to verify the implementation by running actual terminal tests.

1. EXPLORE: Use `list_directory` to see what was built.
2. TEST: 
   - You MUST identify the correct test or build command (e.g., `flutter analyze`, `npm run build`, `pytest`).
   - Run the command using the structured tool action protocol with `run_terminal_command`.
3. VERIFY:
   - If the command succeeds (Exit code 0, no errors), output exclusively 'PASSED'.
   - If the command fails, analyze the output and provide detailed feedback for the DebuggerAgent.

Original Task: $originalTask
Implementation Context:
$codeLog
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];
      final agentService = AgentService(
        provider: aiProvider,
        mode: 'Agent',
        maxToolCalls: 15,
        workspaceManager: workspaceManager,
        projectPathProvider: projectPathProvider,
        memoryService: memoryService,
      );
      
      String response = '';
      await for (final step in agentService.run(history)) {
        if (step.type == AgentStepType.toolCall || step.type == AgentStepType.toolResult) {
          bus.publish(
            AgentEvent(
              sourceAgent: name,
              targetAgent: 'System',
              type: AgentEventType.agentStep,
              payload: step,
            ),
          );
        } else if (step.type == AgentStepType.text || step.type == AgentStepType.finalAnswer) {
          response += step.content;
          bus.publish(
            AgentEvent(
              sourceAgent: name,
              targetAgent: 'User',
              type: AgentEventType.message,
              payload: step.content,
            ),
          );
        }
      }

      if (response.contains('PASSED')) {
        bus.publish(
          AgentEvent(
            sourceAgent: name,
            targetAgent: 'ReviewerAgent',
            type: AgentEventType.taskAssigned,
            payload: AgentHandoff(
              status: 'completed',
              reason: 'Implementation passed testing and is ready for review.',
              artifacts: ['test_summary'],
              evidence: [response],
              nextRecommendedAgent: 'ReviewerAgent',
              data: {
                'originalTask': originalTask,
                'codeLog': '$codeLog\n\nTesting summary:\n$response',
              },
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
              reason: 'Testing passed. Handing off to ReviewerAgent.',
              artifacts: ['test_summary'],
              evidence: [response],
              nextRecommendedAgent: 'ReviewerAgent',
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
              reason: 'Testing failed and requires recovery routing.',
              artifacts: ['test_summary'],
              evidence: [response],
              nextRecommendedAgent: 'SupervisorAgent',
              data: {
                'sourceAgent': name,
                'failure': 'Testing failed. Feedback:\n$response',
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
            reason: 'Failed to complete testing: $e',
            evidence: ['TestingAgent threw an exception.'],
            nextRecommendedAgent: 'SupervisorAgent',
          ).toJson(),
        ),
      );
    }
  }
}
