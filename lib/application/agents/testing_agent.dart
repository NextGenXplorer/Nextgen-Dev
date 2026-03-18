import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../../domain/models/agent_step.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';
import '../../infrastructure/agent/agent_service.dart';
import '../../infrastructure/storage/workspace_manager.dart';

class TestingAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;
  final WorkspaceManager workspaceManager;

  TestingAgent({required this.bus, required this.aiProvider, required this.workspaceManager});

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
      final payload = event.payload as Map<String, dynamic>;
      final codeLog = payload['codeLog'] ?? '';
      final originalTask = payload['originalTask'];

      final prompt =
          '''
You are an ELITE TESTING AGENT. Your job is to verify the implementation by running actual terminal tests.

1. EXPLORE: Use `list_directory` to see what was built.
2. TEST: 
   - You MUST identify the correct test or build command (e.g., `flutter analyze`, `npm run build`, `pytest`).
   - Run the command using `<tool_call>{"name": "run_terminal_command", "command": "..."}</tool_call>`.
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
            targetAgent: 'PreviewAgent',
            type: AgentEventType.taskAssigned,
            payload: 'start',
          ),
        );
        bus.publish(
          AgentEvent(
            sourceAgent: name,
            targetAgent: 'System',
            type: AgentEventType.taskCompleted,
            payload: 'Testing passed. Handing off to PreviewAgent.',
          ),
        );
      } else {
        bus.publish(
          AgentEvent(
            sourceAgent: name,
            targetAgent: 'DebuggerAgent',
            type: AgentEventType.error,
            payload: 'Testing failed. Feedback:\n$response',
          ),
        );
      }
    } catch (e) {
      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskFailed,
          payload: 'Failed to complete testing: $e',
        ),
      );
    }
  }
}
