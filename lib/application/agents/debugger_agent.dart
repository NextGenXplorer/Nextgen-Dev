import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';

class DebuggerAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;

  DebuggerAgent({required this.bus, required this.aiProvider});

  @override
  String get name => 'DebuggerAgent';

  @override
  String get description => 'Analyzes errors and suggests or implements fixes.';

  @override
  bool canHandle(AgentEvent event) {
    return event.targetAgent == name || event.type == AgentEventType.error;
  }

  @override
  Future<void> handleEvent(AgentEvent event) async {
    bus.publish(AgentEvent(
      sourceAgent: name,
      targetAgent: 'System',
      type: AgentEventType.message,
      payload: 'DebuggerAgent analyzing error...',
    ));

    try {
      final errorMessage = event.payload.toString();

      final prompt = '''
You are an expert Debugger. Analyze the following error and provide a fix or explanation.
Error: $errorMessage

Respond with the identified root cause and the suggested code change to fix it.
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];
      final fix = await aiProvider.generate(history);

      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'User',
        type: AgentEventType.message,
        payload: 'Debugger Analysis:\\n$fix',
      ));

      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'System',
        type: AgentEventType.taskCompleted,
        payload: 'Debugging phase complete.',
      ));

    } catch (e) {
      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'System',
        type: AgentEventType.taskFailed,
        payload: 'Debugger failed to analyze error: $e',
      ));
    }
  }
}
