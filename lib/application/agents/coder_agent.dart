import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../../domain/models/agent_step.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';
import '../../infrastructure/agent/agent_service.dart';

class CoderAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;

  CoderAgent({required this.bus, required this.aiProvider});

  @override
  String get name => 'CoderAgent';

  @override
  String get description => 'Generates code and shell commands based on a provided plan.';

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
      payload: 'CoderAgent is executing the plan...',
    ));

    try {
      final payload = event.payload as Map<String, dynamic>;
      final originalTask = payload['originalTask'];
      final plan = payload['plan'];
      final scaffoldLog = payload['scaffoldLog'] ?? '';

      final prompt = '''
You are the Coder Agent in a multi-agent system.
Your job is to write code, modify files, and run terminal commands to fulfill the implementation plan.
Use `edit_file` to modify existing files.
Use `run_terminal_command` to test or build.
Wait for tool results and iteratively build the solution.

Original Task: $originalTask
Plan: $plan
Context from Scaffolder: $scaffoldLog
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];
      final agentService = AgentService(provider: aiProvider, mode: 'Code');
      
      String codeLog = '';
      
      await for (final step in agentService.run(history)) {
         if (step.type == AgentStepType.toolCall) {
            bus.publish(AgentEvent(sourceAgent: name, targetAgent: 'User', type: AgentEventType.message, payload: 'Tool Call: ${step.content}'));
         } else if (step.type == AgentStepType.toolResult) {
            bus.publish(AgentEvent(sourceAgent: name, targetAgent: 'User', type: AgentEventType.message, payload: 'Tool Result: \\n${step.content}'));
         } else if (step.type == AgentStepType.text || step.type == AgentStepType.finalAnswer) {
            codeLog += step.content;
            bus.publish(AgentEvent(sourceAgent: name, targetAgent: 'User', type: AgentEventType.message, payload: step.content));
         }
      }

      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'User',
        type: AgentEventType.message,
        payload: 'The Coder Agent has completed the implementation phase.',
      ));

      // Hand off code to ReviewerAgent
      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'ReviewerAgent',
        type: AgentEventType.taskAssigned,
        payload: {'originalTask': originalTask, 'codeLog': codeLog},
      ));

      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'System',
        type: AgentEventType.taskCompleted,
        payload: 'Coding phase complete. Handed off to ReviewerAgent.',
      ));

    } catch (e) {
      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'System',
        type: AgentEventType.taskFailed,
        payload: 'Failed to generate code: $e',
      ));
    }
  }
}
