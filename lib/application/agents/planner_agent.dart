import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../../domain/models/agent_step.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';
import '../../infrastructure/agent/agent_service.dart';

class PlannerAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;

  PlannerAgent({required this.bus, required this.aiProvider});

  @override
  String get name => 'PlannerAgent';

  @override
  String get description => 'Breaks down user requests into actionable implementation steps.';

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
      payload: 'Planner is analyzing task: ${event.payload}...',
    ));

    try {
      final prompt = '''
You are the Planner Agent in a multi-agent system.
Your job is to break down the user's request into a sequential plan.
You have tools to read the local workspace (list_projects, get_project_context). USE THEM if the user mentions an existing project.
Once you understand the context, output an "# Implementation Plan" with a "## Tasks" checklist (- [ ] task format).
Request: ${event.payload}
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];
      
      // Use AgentService so Planner can use tools!
      final agentService = AgentService(provider: aiProvider, mode: 'Agent');
      String plan = '';
      
      await for (final step in agentService.run(history)) {
         if (step.type == AgentStepType.toolCall) {
            bus.publish(AgentEvent(sourceAgent: name, targetAgent: 'User', type: AgentEventType.message, payload: 'Tool Call: ${step.content}'));
         } else if (step.type == AgentStepType.toolResult) {
            bus.publish(AgentEvent(sourceAgent: name, targetAgent: 'User', type: AgentEventType.message, payload: 'Tool Result: \\n${step.content}'));
         } else if (step.type == AgentStepType.text || step.type == AgentStepType.finalAnswer) {
            plan += step.content;
            bus.publish(AgentEvent(sourceAgent: name, targetAgent: 'User', type: AgentEventType.message, payload: step.content));
         }
      }

      // Hand off to ScaffolderAgent
      // We pass the final plan down
      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'ScaffolderAgent',
        type: AgentEventType.taskAssigned,
        payload: {'originalTask': event.payload, 'plan': plan},
      ));

      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'System',
        type: AgentEventType.taskCompleted,
        payload: 'Planning phase complete. Handed off to ScaffolderAgent.',
      ));
    } catch (e) {
      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'System',
        type: AgentEventType.taskFailed,
        payload: 'Failed to generate plan: $e',
      ));
    }
  }
}
