import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';

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
      payload: 'CoderAgent is writing code based on plan...',
    ));

    try {
      final payload = event.payload as Map<String, dynamic>;
      final originalTask = payload['originalTask'];
      final plan = payload['plan'];

      final prompt = '''
You are an expert Flutter Developer. Follow this plan to accomplish the user's task.
Original Task: $originalTask
Plan: $plan

Write the code necessary to complete this task.
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];
      final code = await aiProvider.generate(history);

      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'User',
        type: AgentEventType.message,
        payload: 'Task Implementation:\\n$code',
      ));

      // Hand off code to ReviewerAgent
      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'ReviewerAgent',
        type: AgentEventType.taskAssigned,
        payload: {'originalTask': originalTask, 'code': code},
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
