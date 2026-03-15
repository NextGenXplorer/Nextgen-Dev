import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';
import '../../infrastructure/services/dev_server_service.dart';

class ServeAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;
  final DevServerService serverService;

  ServeAgent({
    required this.bus,
    required this.aiProvider,
    required this.serverService,
  }) {
    // Pipe server logs to the agent bus
    serverService.logStream.listen((log) {
      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'Terminal',
          type: AgentEventType.message,
          payload: '[Server Log] $log',
        ),
      );
    });
  }

  @override
  String get name => 'ServeAgent';

  @override
  String get description => 'Manages local development server lifecycles.';

  @override
  bool canHandle(AgentEvent event) {
    return event.targetAgent == name &&
        (event.type == AgentEventType.taskAssigned ||
            event.type == AgentEventType.message);
  }

  @override
  Future<void> handleEvent(AgentEvent event) async {
    final payloadStr = event.payload.toString().toLowerCase();

    // Simple intent parsing for the Serve agent wrapper
    if (payloadStr.contains('stop') || payloadStr.contains('kill')) {
      await serverService.stopServer();
      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskCompleted,
          payload: 'Server stopped successfully.',
        ),
      );
      return;
    }

    bus.publish(
      AgentEvent(
        sourceAgent: name,
        targetAgent: 'System',
        type: AgentEventType.message,
        payload: 'ServeAgent interpreting server start request...',
      ),
    );

    try {
      final prompt =
          '''
You are a DevOps assistant. The user wants to start a development server.
Request: ${event.payload}

Identify the best command to run (e.g., "npm run dev", "flutter run", "python -m http.server").
Output strictly in this format: COMMAND|ARG1 ARG2 ARG3
Example: npm|run dev
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];
      final response = (await aiProvider.generate(history)).trim();

      final parts = response.split('|');
      final command = parts[0].trim();
      final args = parts.length > 1 ? parts[1].trim().split(' ') : <String>[];

      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.message,
          payload: 'Starting server command: $command ${args.join(' ')}',
        ),
      );

      await serverService.startServer(command, args);

      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskCompleted,
          payload: 'Server started successfully.',
        ),
      );
    } catch (e) {
      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskFailed,
          payload: 'Failed to start server: $e',
        ),
      );
    }
  }

  @override
  void dispose() {
    serverService.dispose();
  }
}
