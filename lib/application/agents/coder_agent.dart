import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../../domain/models/agent_step.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';
import '../../infrastructure/agent/agent_service.dart';
import '../../infrastructure/storage/workspace_manager.dart';

class CoderAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;

  final WorkspaceManager workspaceManager;
  CoderAgent({
    required this.bus,
    required this.aiProvider,
    required this.workspaceManager,
  });

  @override
  String get name => 'CoderAgent';

  @override
  String get description =>
      'Generates code and shell commands based on a provided plan.';

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
        payload: 'CoderAgent is executing the plan...',
      ),
    );

    try {
      final payload = event.payload as Map<String, dynamic>;
      final originalTask = payload['originalTask'];
      final plan = payload['plan'];
      final scaffoldLog = payload['scaffoldLog'] ?? '';

      final prompt =
          '''
You are the ELITE CODER AGENT in a multi-agent system.
Your job is to write PERFECT, production-ready code to fulfill the implementation plan.

1. EXECUTION RULES:
   - Use `edit_file` to modify existing files. Use `create_file` for new ones.
   - Use `run_terminal_command` to test, build, or analyze.
   - Wait for tool results and iteratively build the solution.
   
2. QUALITY & DESIGN STANDARDS:
   - For UI/Frontend tasks, you MUST implement premium, modern aesthetics. If the Planner specified design constraints (e.g., animations, glassmorphism, specific color palettes), follow them strictly. DO NOT build generic or basic UIs.
   - For Backend/Logic tasks, write robust, secure, and type-safe code with proper error handling.
   - Do not leave FIXME or TODO comments. Write complete implementations.

3. TESTING & VERIFICATION (MANDATORY):
   - You MUST run a terminal command (e.g., `flutter analyze`, `npm run build`, or `npm test`) to verify your code compiles and runs without errors.
   - If the command returns errors, you MUST use `edit_file` to fix them and re-run the test!
   - You are NOT finished until the codebase is completely error-free.

Original Task: $originalTask
Plan: $plan
Context from Scaffolder: $scaffoldLog
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];
      final agentService = AgentService(
        provider: aiProvider,
        mode: 'Code',
        workspaceManager: workspaceManager,
      );

      String codeLog = '';

      await for (final step in agentService.run(history)) {
        if (step.type == AgentStepType.toolCall ||
            step.type == AgentStepType.toolResult) {
          bus.publish(
            AgentEvent(
              sourceAgent: name,
              targetAgent: 'System',
              type: AgentEventType.agentStep,
              payload: step,
            ),
          );
        } else if (step.type == AgentStepType.text ||
            step.type == AgentStepType.finalAnswer) {
          codeLog += step.content;
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

      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'User',
          type: AgentEventType.message,
          payload: 'The Coder Agent has completed the implementation phase.',
        ),
      );

      // Hand off code to ReviewerAgent
      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'ReviewerAgent',
          type: AgentEventType.taskAssigned,
          payload: {'originalTask': originalTask, 'codeLog': codeLog},
        ),
      );

      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskCompleted,
          payload: 'Coding phase complete. Handed off to ReviewerAgent.',
        ),
      );
    } catch (e) {
      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskFailed,
          payload: 'Failed to generate code: $e',
        ),
      );
    }
  }
}
