import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';
import '../../infrastructure/services/dev_server_service.dart';

class PreviewAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;
  final DevServerService serverService;

  PreviewAgent({
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
  String get name => 'PreviewAgent';

  @override
  String get description => 'Installs dependencies and manages local development server lifecycles for project preview.';

  @override
  bool canHandle(AgentEvent event) {
    return event.targetAgent == name &&
        (event.type == AgentEventType.taskAssigned ||
            event.type == AgentEventType.message);
  }

  @override
  Future<void> handleEvent(AgentEvent event) async {
    final payloadStr = event.payload.toString().toLowerCase();

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
        targetAgent: 'User',
        type: AgentEventType.message,
        payload: '🌐 PreviewAgent preparing environment & starting server...',
      ),
    );

    try {
      final prompt =
          '''
You are a PREVIEW & DEVOPS AGENT. Your job is to install packages and start a dev server.

1. INSTALL: Identify and run the package install command (e.g., `npm install`, `flutter pub get`).
2. SERVE: Identify the start command (e.g., `npm run dev`, `flutter run`).

Output strictly in this format: INSTALL_CMD|SERVE_CMD
Example: npm install|npm run dev
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];
      final response = (await aiProvider.generate(history)).trim();

      final parts = response.split('|');
      final installCmdLine = parts[0].trim();
      final serveCmdLine = parts.length > 1 ? parts[1].trim() : '';

      // Run Install
      if (installCmdLine.isNotEmpty) {
        final iParts = installCmdLine.split(' ');
        await serverService.startServer(iParts[0], iParts.sublist(1));
        // Wait a bit for install to finish - in a real app we'd wait for process completion
        await Future.delayed(const Duration(seconds: 5));
      }

      // Run Serve
      if (serveCmdLine.isNotEmpty) {
        final sParts = serveCmdLine.split(' ');
        await serverService.startServer(sParts[0], sParts.sublist(1));
      }

      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskCompleted,
          payload: 'Environment prepared and server started.',
        ),
      );

      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'User',
          type: AgentEventType.message,
          payload: 'Project is ready! Check the preview window.',
        ),
      );
    } catch (e) {
      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskFailed,
          payload: 'Failed in preview phase: $e',
        ),
      );
    }
  }

  @override
  void dispose() {
    serverService.dispose();
  }
}
