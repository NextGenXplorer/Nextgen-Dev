import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/interfaces/agent.dart';
import '../domain/models/agent_event.dart';
import 'agent_bus.dart';

import 'agents/planner_agent.dart';
import 'agents/scaffolder_agent.dart';
import 'agents/coder_agent.dart';
import 'agents/testing_agent.dart';
import 'agents/debugger_agent.dart';
import 'agents/deployer_agent.dart';
import 'agents/preview_agent.dart';
import 'agents/requirements_agent.dart';
import 'providers/ai_service_provider.dart';
import '../infrastructure/services/git_service.dart';
import '../infrastructure/services/dev_server_service.dart';
import '../infrastructure/services/log_monitor_service.dart';
import 'providers/storage_providers.dart';

// Provide a default path for the GitService workspace
final gitServiceProvider = Provider<GitService>((ref) {
  return GitService(workingDirectory: '.'); // Root of the flutter app for now
});

final devServerServiceProvider = Provider<DevServerService>((ref) {
  return DevServerService(workingDirectory: '.');
});

final logMonitorServiceProvider = Provider<LogMonitorService>((ref) {
  final service = LogMonitorService();
  ref.onDispose(() => service.dispose());
  return service;
});

final orchestratorProvider = Provider<AgentOrchestrator>((ref) {
  final bus = ref.watch(agentBusProvider);
  final aiProviderFuture = ref.watch(aiProviderServiceProvider);
  final gitService = ref.watch(gitServiceProvider);
  final devServerService = ref.watch(devServerServiceProvider);
  final logMonitorService = ref.watch(logMonitorServiceProvider);
  final workspaceManager = ref.watch(workspaceManagerProvider);

  final orchestrator = AgentOrchestrator(
    bus: bus,
    logMonitor: logMonitorService,
  );

  // We need the AIProvider to be concrete for the agents to function.
  // In a real app we might handle loading states, but for early sprint logic:
  aiProviderFuture.whenData((ai) {
    if (ai != null) {
      orchestrator.registerAgent(RequirementsAgent(bus: bus, aiProvider: ai, workspaceManager: workspaceManager));
      orchestrator.registerAgent(PlannerAgent(bus: bus, aiProvider: ai, workspaceManager: workspaceManager));
      orchestrator.registerAgent(ScaffolderAgent(bus: bus, aiProvider: ai, workspaceManager: workspaceManager));
      orchestrator.registerAgent(CoderAgent(bus: bus, aiProvider: ai, workspaceManager: workspaceManager));
      orchestrator.registerAgent(TestingAgent(bus: bus, aiProvider: ai, workspaceManager: workspaceManager));
      orchestrator.registerAgent(DebuggerAgent(bus: bus, aiProvider: ai, workspaceManager: workspaceManager));
      orchestrator.registerAgent(
        DeployerAgent(bus: bus, aiProvider: ai, gitService: gitService),
      );
      orchestrator.registerAgent(
        PreviewAgent(bus: bus, aiProvider: ai, serverService: devServerService),
      );
    }
  });

  ref.onDispose(() => orchestrator.dispose());
  return orchestrator;
});

class AgentOrchestrator {
  final AgentBus bus;
  final List<Agent> _agents = [];
  late StreamSubscription<AgentEvent> _subscription;
  final LogMonitorService? logMonitor;

  // Track retries per task description
  final Map<String, int> _retryCounts = {};
  static const int _maxRetries = 2;

  AgentOrchestrator({required this.bus, this.logMonitor}) {
    _subscription = bus.eventStream.listen(_onEvent);

    // Wire up crash monitoring
    if (logMonitor != null) {
      logMonitor!.errorStream.listen((errorLine) {
        bus.publish(
          AgentEvent(
            sourceAgent: 'System (Logcat)',
            targetAgent: 'DebuggerAgent',
            type: AgentEventType.error,
            payload: 'DEVICE CRASH DETECTED:\\n$errorLine',
          ),
        );
      });
      logMonitor!.startMonitoring();
    }
  }

  void registerAgent(Agent agent) {
    _agents.add(agent);
  }

  void _onEvent(AgentEvent event) {
    // Basic retry interceptor
    if (event.type == AgentEventType.taskFailed) {
      _handleFailure(event);
    }

    // Requirements gathered → enrich the task and send to PlannerAgent.
    if (event.type == AgentEventType.requirementsGathered) {
      final p = event.payload as Map<String, dynamic>;
      final enrichedTask =
          '${p['originalTask']}\n\n---\n${p['gatheredRequirements']}';
      bus.publish(
        AgentEvent(
          sourceAgent: 'Orchestrator',
          targetAgent: 'PlannerAgent',
          type: AgentEventType.taskAssigned,
          payload: enrichedTask,
        ),
      );
      return;
    }

    // Plan approval lifecycle.
    if (event.type == AgentEventType.planApproved) {
      bus.publish(
        AgentEvent(
          sourceAgent: 'Orchestrator',
          targetAgent: 'ScaffolderAgent',
          type: AgentEventType.taskAssigned,
          payload: event.payload,
        ),
      );
      return;
    }

    if (event.type == AgentEventType.planRejected) {
      bus.publish(
        AgentEvent(
          sourceAgent: 'Orchestrator',
          targetAgent: 'PlannerAgent',
          type: AgentEventType.taskAssigned,
          payload: event.payload,
        ),
      );
      return;
    }

    // Terminal task completion signal.
    if (event.type == AgentEventType.taskCompleted) {
      if (event.sourceAgent == 'PreviewAgent' ||
          event.sourceAgent == 'DeployerAgent') {
        bus.publish(
          AgentEvent(
            sourceAgent: 'Orchestrator',
            targetAgent: 'System',
            type: AgentEventType.agentFinished,
            payload: 'chain_completed',
          ),
        );
      }
    }

    for (final agent in _agents) {
      if (agent.canHandle(event)) {
        agent.handleEvent(event).catchError((e) {
          bus.publish(
            AgentEvent(
              sourceAgent: 'Orchestrator',
              targetAgent: 'System',
              type: AgentEventType.error,
              payload: 'Error in agent ${agent.name}: $e',
            ),
          );
        });
      }
    }
  }

  void _handleFailure(AgentEvent event) {
    final payloadStr = event.payload.toString();
    final currentRetries = _retryCounts[payloadStr] ?? 0;

    if (currentRetries < _maxRetries) {
      _retryCounts[payloadStr] = currentRetries + 1;
      bus.publish(
        AgentEvent(
          sourceAgent: 'Orchestrator',
          targetAgent: 'System',
          type: AgentEventType.message,
          payload:
              'Retrying task (Attempt ${currentRetries + 1} of $_maxRetries) due to failure: $payloadStr',
        ),
      );

      // We route back to the debugger to analyze the failure
      bus.publish(
        AgentEvent(
          sourceAgent: 'Orchestrator',
          targetAgent: 'DebuggerAgent',
          type: AgentEventType.error,
          payload: payloadStr,
        ),
      );
    } else {
      bus.publish(
        AgentEvent(
          sourceAgent: 'Orchestrator',
          targetAgent: 'User',
          type: AgentEventType.message,
          payload:
              'Critical Failure: Max retries exceeded for task. Error: $payloadStr',
        ),
      );
      bus.publish(
        AgentEvent(
          sourceAgent: 'Orchestrator',
          targetAgent: 'System',
          type: AgentEventType.agentFinished,
          payload: 'exceeded_retries',
        ),
      );
    }
  }

  void dispatchTask(String taskDescription) {
    _retryCounts[taskDescription] = 0; // Reset retries for new task
    bus.publish(
      AgentEvent(
        sourceAgent: 'User',
        targetAgent: 'RequirementsAgent', // Always starts with requirements gathering
        type: AgentEventType.taskAssigned,
        payload: taskDescription,
      ),
    );
  }

  /// Called when the user sends a follow-up answer to the RequirementsAgent.
  void dispatchRequirementsFollowUp({
    required String originalTask,
    required String userAnswer,
  }) {
    bus.publish(
      AgentEvent(
        sourceAgent: 'User',
        targetAgent: 'RequirementsAgent',
        type: AgentEventType.taskAssigned,
        payload: {
          'originalTask': originalTask,
          'followUp': userAnswer,
        },
      ),
    );
  }

  void dispose() {
    _subscription.cancel();
    for (var agent in _agents) {
      agent.dispose();
    }
    _agents.clear();
  }
}
