import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../../domain/models/agent_handoff.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';
import '../../infrastructure/services/agent_memory_service.dart';
import '../../infrastructure/services/dev_server_service.dart';

class PreviewAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;
  final DevServerService serverService;
  final AgentMemoryService memoryService;
  final String? Function()? projectPathProvider;

  PreviewAgent({
    required this.bus,
    required this.aiProvider,
    required this.serverService,
    required this.memoryService,
    this.projectPathProvider,
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
    final normalizedPayload = AgentHandoff.unwrapData(event.payload);
    final payloadStr = normalizedPayload.toString().toLowerCase();

    if (payloadStr.contains('stop') || payloadStr.contains('kill')) {
      await serverService.stopServer();
      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskCompleted,
          payload: AgentHandoff(
            status: 'completed',
            reason: 'Server stopped successfully.',
            evidence: ['PreviewAgent stopped the dev server.'],
          ).toJson(),
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
      final commandsRun = <String>[];
      final memoryContext = await memoryService.buildExecutionContext(
        task: normalizedPayload.toString(),
        projectPath: projectPathProvider?.call(),
        agentName: name,
      );
      final prompt =
          '''
You are a PREVIEW & DEVOPS AGENT. Your job is to install packages and start a dev server.

$memoryContext

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
        commandsRun.add(installCmdLine);
        await serverService.startServer(iParts[0], iParts.sublist(1));
        // Wait a bit for install to finish - in a real app we'd wait for process completion
        await Future.delayed(const Duration(seconds: 5));
      }

      // Run Serve
      if (serveCmdLine.isNotEmpty) {
        final sParts = serveCmdLine.split(' ');
        commandsRun.add(serveCmdLine);
        await serverService.startServer(sParts[0], sParts.sublist(1));
      }

      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskCompleted,
          payload: AgentHandoff(
            status: 'completed',
            reason: 'Environment prepared and server started.',
            commandsRun: commandsRun,
            evidence: ['PreviewAgent started the preview environment.'],
          ).toJson(),
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
          payload: AgentHandoff(
            status: 'failed',
            reason: 'Failed in preview phase: $e',
            evidence: ['PreviewAgent threw an exception.'],
          ).toJson(),
        ),
      );
    }
  }

  @override
  void dispose() {
    serverService.dispose();
  }
}
