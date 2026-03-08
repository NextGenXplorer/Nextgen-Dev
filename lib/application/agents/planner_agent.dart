import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';

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
You are a Staff Software Engineer. Break down the following request into a sequential plan.
Only reply with the ordered steps necessary to implement this. Do not write code.
Request: ${event.payload}
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];
      final plan = await aiProvider.generate(history);

      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'System',
        type: AgentEventType.message,
        payload: 'Plan generated:\\n$plan',
      ));

      // Hand off to ScaffolderAgent
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
