import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/interfaces/agent.dart';
import '../domain/models/agent_event.dart';
import '../domain/models/agent_handoff.dart';
import '../domain/models/agent_run.dart';
import 'agent_bus.dart';

import 'agents/planner_agent.dart';
import 'agents/scaffolder_agent.dart';
import 'agents/coder_agent.dart';
import 'agents/testing_agent.dart';
import 'agents/debugger_agent.dart';
import 'agents/deployer_agent.dart';
import 'agents/preview_agent.dart';
import 'agents/reviewer_agent.dart';
import 'agents/requirements_agent.dart';
import 'agents/serve_agent.dart';
import 'agents/supervisor_agent.dart';
import 'providers/ai_service_provider.dart';
import '../infrastructure/services/git_service.dart';
import '../infrastructure/services/dev_server_service.dart';
import '../infrastructure/services/log_monitor_service.dart';
import '../infrastructure/services/agent_run_service.dart';
import '../infrastructure/services/agent_eval_service.dart';
import '../infrastructure/services/agent_memory_service.dart';
import 'providers/storage_providers.dart';
import 'providers/agent_session_provider.dart';

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
  final agentRunService = ref.watch(agentRunServiceProvider);
  final agentEvalService = ref.watch(agentEvalServiceProvider);
  final agentMemoryService = ref.watch(agentMemoryServiceProvider);
  final agentSession = ref.watch(agentSessionProvider.notifier);

  final orchestrator = AgentOrchestrator(
    bus: bus,
    logMonitor: logMonitorService,
    runService: agentRunService,
    evalService: agentEvalService,
    memoryService: agentMemoryService,
    sessionNotifier: agentSession,
  );

  // We need the AIProvider to be concrete for the agents to function.
  // In a real app we might handle loading states, but for early sprint logic:
  aiProviderFuture.whenData((ai) {
    if (ai != null) {
      final projectPathProvider = () => agentSession.state.activeProjectPath;
      orchestrator.registerAgent(RequirementsAgent(bus: bus, aiProvider: ai, memoryService: agentMemoryService, workspaceManager: workspaceManager, projectPathProvider: projectPathProvider));
      orchestrator.registerAgent(PlannerAgent(bus: bus, aiProvider: ai, workspaceManager: workspaceManager, memoryService: agentMemoryService, projectPathProvider: projectPathProvider));
      orchestrator.registerAgent(ScaffolderAgent(bus: bus, aiProvider: ai, workspaceManager: workspaceManager, memoryService: agentMemoryService, projectPathProvider: projectPathProvider));
      orchestrator.registerAgent(CoderAgent(bus: bus, aiProvider: ai, workspaceManager: workspaceManager, memoryService: agentMemoryService, projectPathProvider: projectPathProvider));
      orchestrator.registerAgent(TestingAgent(bus: bus, aiProvider: ai, workspaceManager: workspaceManager, memoryService: agentMemoryService, projectPathProvider: projectPathProvider));
      orchestrator.registerAgent(DebuggerAgent(bus: bus, aiProvider: ai, workspaceManager: workspaceManager, memoryService: agentMemoryService, projectPathProvider: projectPathProvider));
      orchestrator.registerAgent(SupervisorAgent(bus: bus, aiProvider: ai, memoryService: agentMemoryService, projectPathProvider: projectPathProvider));
      orchestrator.registerAgent(ReviewerAgent(bus: bus, aiProvider: ai, memoryService: agentMemoryService, projectPathProvider: projectPathProvider));
      orchestrator.registerAgent(
        DeployerAgent(bus: bus, aiProvider: ai, gitService: gitService, memoryService: agentMemoryService, projectPathProvider: projectPathProvider),
      );
      orchestrator.registerAgent(
        ServeAgent(bus: bus, aiProvider: ai, serverService: devServerService, memoryService: agentMemoryService, projectPathProvider: projectPathProvider),
      );
      orchestrator.registerAgent(
        PreviewAgent(bus: bus, aiProvider: ai, serverService: devServerService, memoryService: agentMemoryService, projectPathProvider: projectPathProvider),
      );
      orchestrator.markAgentsReady();
    }
  });

  ref.onDispose(() => orchestrator.dispose());
  return orchestrator;
});

class AgentOrchestrator {
  final AgentBus bus;
  final List<Agent> _agents = [];
  final Set<String> _registeredAgentNames = {};
  final List<void Function()> _pendingActions = [];
  late StreamSubscription<AgentEvent> _subscription;
  final LogMonitorService? logMonitor;
  final AgentRunService runService;
  final AgentEvalService evalService;
  final AgentMemoryService memoryService;
  final AgentSessionNotifier sessionNotifier;
  bool _agentsReady = false;
  String? _activeRunId;
  Timer? _watchdogTimer;
  bool _stalledRunHandled = false;

  // Track retries per task description
  final Map<String, int> _retryCounts = {};
  static const int _maxRetries = 2;

  AgentOrchestrator({
    required this.bus,
    this.logMonitor,
    required this.runService,
    required this.evalService,
    required this.memoryService,
    required this.sessionNotifier,
  }) {
    _subscription = bus.eventStream.listen(_onEvent);
    unawaited(_restoreLatestRun());
    _watchdogTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _checkForStalledRun(),
    );

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
    if (_registeredAgentNames.contains(agent.name)) {
      return;
    }
    _registeredAgentNames.add(agent.name);
    _agents.add(agent);
  }

  void markAgentsReady() {
    if (_agentsReady) return;
    _agentsReady = true;

    if (_pendingActions.isNotEmpty) {
      bus.publish(
        AgentEvent(
          sourceAgent: 'Orchestrator',
          targetAgent: 'User',
          type: AgentEventType.message,
          payload: 'All agents are ready. Continuing the workflow...',
        ),
      );
      _trace(
        source: 'Orchestrator',
        target: 'User',
        type: 'agents_ready',
        summary: 'All agents are ready. Continuing the workflow...',
        phase: 'ready',
        activeAgent: 'Orchestrator',
        reason: 'Agent fleet initialized',
      );
    }

    final queued = List<void Function()>.from(_pendingActions);
    _pendingActions.clear();
    for (final action in queued) {
      action();
    }
  }

  void _runWhenReady(
    void Function() action, {
    String? waitingMessage,
  }) {
    if (_agentsReady) {
      action();
      return;
    }

    if (waitingMessage != null) {
      bus.publish(
        AgentEvent(
          sourceAgent: 'Orchestrator',
          targetAgent: 'User',
          type: AgentEventType.message,
          payload: waitingMessage,
        ),
      );
      _trace(
        source: 'Orchestrator',
        target: 'User',
        type: 'waiting',
        summary: waitingMessage,
        phase: 'queued',
        activeAgent: 'Orchestrator',
        reason: 'Waiting for agents to initialize',
      );
    }
    _pendingActions.add(action);
  }

  void _onEvent(AgentEvent event) {
    _recordLifecycleEvent(event);

    // Basic retry interceptor
    if (event.type == AgentEventType.taskFailed) {
      _handleFailure(event);
    }

    // Requirements gathered → enrich the task and send to PlannerAgent.
    if (event.type == AgentEventType.requirementsGathered) {
      final p =
          AgentHandoff.unwrapData(event.payload) as Map<String, dynamic>;
      final enrichedTask =
          '${p['originalTask']}\n\n---\n${p['gatheredRequirements']}';
      unawaited(
        memoryService.rememberProjectMemory(
          p['gatheredRequirements']?.toString() ?? '',
          projectPath: sessionNotifier.state.activeProjectPath,
          agentName: 'RequirementsAgent',
          fingerprint:
              'requirements:${p['originalTask']?.toString().hashCode ?? 0}',
        ),
      );
      bus.publish(
        AgentEvent(
          sourceAgent: 'Orchestrator',
          targetAgent: 'PlannerAgent',
          type: AgentEventType.taskAssigned,
          payload: AgentHandoff(
            status: 'completed',
            reason: 'Requirements were gathered and enriched for planning.',
            artifacts: ['requirements_brief'],
            evidence: [p['gatheredRequirements']?.toString() ?? ''],
            nextRecommendedAgent: 'PlannerAgent',
            data: {'originalTask': enrichedTask},
          ).toJson(),
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
    final payloadStr = AgentHandoff.summarize(event.payload);
    final currentRetries = _retryCounts[payloadStr] ?? 0;
    unawaited(
      memoryService.rememberFailurePattern(
        payloadStr,
        projectPath: sessionNotifier.state.activeProjectPath,
        agentName: event.sourceAgent,
        fingerprint: 'failure:${event.sourceAgent}:${payloadStr.hashCode}',
      ),
    );

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
      _trace(
        source: 'Orchestrator',
        target: 'SupervisorAgent',
        type: 'retry',
        summary: payloadStr,
        phase: 'debugging',
        activeAgent: 'SupervisorAgent',
        reason: 'Supervisor deciding recovery path after task failure',
        retryCount: currentRetries + 1,
      );

      // Route back through the supervisor so it can pick debugger vs re-plan.
      bus.publish(
        AgentEvent(
          sourceAgent: 'Orchestrator',
          targetAgent: 'SupervisorAgent',
          type: AgentEventType.taskAssigned,
          payload: AgentHandoff(
            status: 'failed',
            reason: 'A workflow phase failed and needs supervisory routing.',
            artifacts: ['failure_report'],
            evidence: [payloadStr],
            nextRecommendedAgent: 'SupervisorAgent',
            data: {
              'sourceAgent': event.sourceAgent,
              'failure': payloadStr,
              'retryCount': currentRetries + 1,
            },
          ).toJson(),
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
      _trace(
        source: 'Orchestrator',
        target: 'User',
        type: 'failed',
        summary: payloadStr,
        status: 'failed',
        phase: 'failed',
        activeAgent: 'Orchestrator',
        reason: 'Max retries exceeded',
        retryCount: currentRetries,
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
    unawaited(_startRun(taskDescription));
    unawaited(
      memoryService.captureUserPreferencesFromTask(
        taskDescription,
        projectPath: sessionNotifier.state.activeProjectPath,
      ),
    );
    _runWhenReady(
      () => bus.publish(
        AgentEvent(
          sourceAgent: 'User',
          targetAgent: 'RequirementsAgent', // Always starts with requirements gathering
          type: AgentEventType.taskAssigned,
          payload: AgentHandoff(
            status: 'queued',
            reason: 'User submitted a new task for requirements gathering.',
            artifacts: ['user_task'],
            evidence: [taskDescription],
            nextRecommendedAgent: 'RequirementsAgent',
            data: {'task': taskDescription},
          ).toJson(),
        ),
      ),
      waitingMessage: 'Initializing agent team and preparing your workflow...',
    );
  }

  /// Called when the user sends a follow-up answer to the RequirementsAgent.
  void dispatchRequirementsFollowUp({
    required String originalTask,
    required String userAnswer,
  }) {
    _runWhenReady(
      () => bus.publish(
        AgentEvent(
          sourceAgent: 'User',
          targetAgent: 'RequirementsAgent',
          type: AgentEventType.taskAssigned,
          payload: AgentHandoff(
            status: 'provided',
            reason: 'User provided clarification for requirements gathering.',
            artifacts: ['requirements_follow_up'],
            evidence: [userAnswer],
            nextRecommendedAgent: 'RequirementsAgent',
            data: {
              'originalTask': originalTask,
              'followUp': userAnswer,
            },
          ).toJson(),
        ),
      ),
      waitingMessage: 'Finalizing agent startup before sending your clarification...',
    );
    _trace(
      source: 'User',
      target: 'RequirementsAgent',
      type: 'requirements_follow_up',
      summary: userAnswer,
      phase: 'requirements',
      activeAgent: 'RequirementsAgent',
      reason: 'User answered requirements follow-up',
    );
  }

  bool hasAgent(String agentName) => _registeredAgentNames.contains(agentName);

  void approvePlan(Map<String, dynamic> payload) {
    unawaited(
      memoryService.rememberRepoMemory(
        payload['plan']?.toString() ?? '',
        agentName: 'PlannerAgent',
        fingerprint:
            'plan:${payload['originalTask']?.toString().hashCode ?? 0}',
      ),
    );
    _runWhenReady(
      () {
        if (!hasAgent('ScaffolderAgent')) {
          bus.publish(
            AgentEvent(
              sourceAgent: 'Orchestrator',
              targetAgent: 'User',
              type: AgentEventType.message,
              payload:
                  'ScaffolderAgent is unavailable, so implementation cannot begin yet.',
            ),
          );
          bus.publish(
            AgentEvent(
              sourceAgent: 'Orchestrator',
              targetAgent: 'System',
              type: AgentEventType.taskFailed,
              payload: AgentHandoff(
                status: 'failed',
                reason:
                    'Plan approval failed because ScaffolderAgent was not registered.',
                evidence: ['ScaffolderAgent missing during plan approval.'],
                nextRecommendedAgent: 'User',
              ).toJson(),
            ),
          );
          return;
        }

        _trace(
          source: 'User',
          target: 'ScaffolderAgent',
          type: 'plan_approved',
          summary: payload['originalTask']?.toString() ?? 'plan approved',
          phase: 'scaffolding',
          activeAgent: 'ScaffolderAgent',
          reason: 'User approved implementation plan',
        );
        bus.publish(
          AgentEvent(
            sourceAgent: 'Orchestrator',
            targetAgent: 'User',
            type: AgentEventType.message,
            payload: 'Plan approved. Starting scaffolding and implementation...',
          ),
        );
        bus.publish(
          AgentEvent(
            sourceAgent: 'Orchestrator',
            targetAgent: 'ScaffolderAgent',
            type: AgentEventType.taskAssigned,
            payload: AgentHandoff(
              status: 'approved',
              reason: 'User approved the plan and execution can begin.',
              artifacts: ['implementation_plan'],
              evidence: [payload['plan']?.toString() ?? ''],
              nextRecommendedAgent: 'ScaffolderAgent',
              data: payload,
            ).toJson(),
          ),
        );
      },
      waitingMessage: 'Preparing the agent team before implementation starts...',
    );
  }

  Future<void> _startRun(String taskDescription) async {
    final run = await runService.createRun(taskDescription);
    _activeRunId = run.id;
    _stalledRunHandled = false;
    sessionNotifier.setExecutionMetadata(
      runId: run.id,
      phase: run.currentPhase,
      activeAgent: run.activeAgent,
      reason: 'Run created',
    );
  }

  Future<void> _restoreLatestRun() async {
    final run = await runService.getLatestActiveRun();
    if (run == null) return;

    _activeRunId = run.id;
    sessionNotifier.setExecutionMetadata(
      runId: run.id,
      phase: run.currentPhase,
      activeAgent: run.activeAgent,
      reason: run.lastTransitionReason,
    );

    bus.publish(
      AgentEvent(
        sourceAgent: 'Orchestrator',
        targetAgent: 'User',
        type: AgentEventType.message,
        payload:
            'Recovered in-progress run at phase "${run.currentPhase}"${run.activeAgent != null ? ' with ${run.activeAgent}' : ''}.',
      ),
    );
  }

  Future<void> _checkForStalledRun() async {
    final runId = _activeRunId;
    if (runId == null || _stalledRunHandled) return;

    final run = await runService.getById(runId);
    if (run == null || run.status != 'running') return;

    final now = DateTime.now();
    final deadlineAt = run.deadlineAt;
    if (deadlineAt == null || now.isBefore(deadlineAt)) return;

    _stalledRunHandled = true;

    final summary =
        'Run exceeded deadline in phase "${run.currentPhase}"${run.activeAgent != null ? ' while waiting on ${run.activeAgent}' : ''}.';

    bus.publish(
      AgentEvent(
        sourceAgent: 'Orchestrator',
        targetAgent: 'User',
        type: AgentEventType.message,
        payload: 'Watchdog detected a stalled run. Attempting recovery...',
      ),
    );
    _trace(
      source: 'Orchestrator',
      target: 'SupervisorAgent',
      type: 'watchdog_stall',
      summary: summary,
      phase: 'debugging',
      activeAgent: 'SupervisorAgent',
      reason: 'Supervisor handling watchdog-detected stalled run',
      status: 'running',
    );

    bus.publish(
      AgentEvent(
        sourceAgent: 'Orchestrator',
        targetAgent: 'SupervisorAgent',
        type: AgentEventType.taskAssigned,
        payload: AgentHandoff(
          status: 'failed',
          reason: 'Watchdog detected a stalled run that needs supervisory routing.',
          artifacts: ['watchdog_report'],
          evidence: [summary],
          nextRecommendedAgent: 'SupervisorAgent',
          data: {
            'sourceAgent': 'Watchdog',
            'failure': summary,
            'retryCount': 999,
          },
        ).toJson(),
      ),
    );
  }

  void _recordLifecycleEvent(AgentEvent event) {
    switch (event.type) {
      case AgentEventType.taskAssigned:
      case AgentEventType.taskCompleted:
      case AgentEventType.taskFailed:
      case AgentEventType.error:
      case AgentEventType.planReady:
      case AgentEventType.awaitingRequirements:
      case AgentEventType.requirementsGathered:
      case AgentEventType.agentFinished:
        _trace(
          source: event.sourceAgent,
          target: event.targetAgent,
          type: event.type.name,
          summary: AgentHandoff.summarize(event.payload),
          phase: _phaseForEvent(event),
          status: _statusForEvent(event),
          activeAgent: _activeAgentForEvent(event),
          reason: _reasonForEvent(event),
        );
        break;
      default:
        break;
    }

    if (event.type == AgentEventType.agentFinished) {
      unawaited(_gradeActiveRun());
    }
  }

  Future<void> _gradeActiveRun() async {
    final runId = _activeRunId;
    if (runId == null) return;

    final run = await runService.getById(runId);
    if (run == null) return;

    final result = await evalService.gradeRun(
      run,
      projectPath: sessionNotifier.state.activeProjectPath,
    );

    if (run.status == 'completed') {
      final relevantTraces = run.traces
          .where(
            (trace) =>
                trace.type == 'taskAssigned' ||
                trace.type == 'taskCompleted' ||
                trace.type == 'planReady',
          )
          .take(8)
          .map((trace) => '${trace.source}→${trace.target}: ${trace.summary}')
          .join(' | ');
      await memoryService.rememberSuccessfulWorkflow(
        'Task: ${run.taskDescription}\nWorkflow: $relevantTraces',
        projectPath: sessionNotifier.state.activeProjectPath,
        fingerprint: 'workflow:${run.taskDescription.hashCode}',
        metadata: {'score': result.score},
      );
    }

    final score = (result.score * 100).toStringAsFixed(0);
    bus.publish(
      AgentEvent(
        sourceAgent: 'Orchestrator',
        targetAgent: 'User',
        type: AgentEventType.message,
        payload: 'Auto-eval finished for run ${run.id}. Score: $score%',
      ),
    );
    _trace(
      source: 'Orchestrator',
      target: 'User',
      type: 'auto_eval',
      summary: 'Auto-eval score $score% for run ${run.id}',
      phase: 'evaluation',
      activeAgent: 'Orchestrator',
      reason: 'Finished run graded automatically',
      status: run.status,
    );
  }

  String _phaseForEvent(AgentEvent event) {
    if (event.type == AgentEventType.awaitingRequirements) return 'requirements';
    if (event.type == AgentEventType.requirementsGathered) return 'planning';
    if (event.type == AgentEventType.planReady) return 'awaiting_approval';
    if (event.sourceAgent == 'ScaffolderAgent' ||
        event.targetAgent == 'ScaffolderAgent') {
      return 'scaffolding';
    }
    if (event.sourceAgent == 'CoderAgent' || event.targetAgent == 'CoderAgent') {
      return 'coding';
    }
    if (event.sourceAgent == 'TestingAgent' ||
        event.targetAgent == 'TestingAgent') {
      return 'testing';
    }
    if (event.sourceAgent == 'ReviewerAgent' ||
        event.targetAgent == 'ReviewerAgent') {
      return 'review';
    }
    if (event.sourceAgent == 'PreviewAgent' ||
        event.targetAgent == 'PreviewAgent') {
      return 'preview';
    }
    if (event.sourceAgent == 'DebuggerAgent' ||
        event.targetAgent == 'DebuggerAgent') {
      return 'debugging';
    }
    if (event.sourceAgent == 'SupervisorAgent' ||
        event.targetAgent == 'SupervisorAgent') {
      return 'supervision';
    }
    return 'running';
  }

  String _statusForEvent(AgentEvent event) {
    if (event.type == AgentEventType.taskFailed) return 'running';
    if (event.type == AgentEventType.agentFinished) {
      return event.payload == 'chain_completed' ? 'completed' : 'failed';
    }
    return 'running';
  }

  String _activeAgentForEvent(AgentEvent event) {
    if (event.type == AgentEventType.taskAssigned) return event.targetAgent;
    if (event.sourceAgent.isNotEmpty && event.sourceAgent != 'User') {
      return event.sourceAgent;
    }
    return event.targetAgent;
  }

  String _reasonForEvent(AgentEvent event) {
    switch (event.type) {
      case AgentEventType.awaitingRequirements:
        return 'Requirements agent requested clarification';
      case AgentEventType.requirementsGathered:
        return 'Requirements were gathered successfully';
      case AgentEventType.planReady:
        return 'Planner produced an implementation plan';
      case AgentEventType.taskAssigned:
        return 'Task handed to next workflow agent';
      case AgentEventType.taskCompleted:
        return 'Agent completed its assigned phase';
      case AgentEventType.taskFailed:
        return 'Agent reported a failed phase';
      case AgentEventType.error:
        return 'Error routed through orchestration';
      case AgentEventType.agentFinished:
        return 'Workflow terminated';
      default:
        return 'Workflow event recorded';
    }
  }

  void _trace({
    required String source,
    required String target,
    required String type,
    required String summary,
    String? status,
    String? phase,
    String? activeAgent,
    String? reason,
    int? retryCount,
  }) {
    final runId = _activeRunId;
    if (runId == null) return;

    final resolvedPhase = phase ?? 'running';
    final resolvedAgent = activeAgent;
    final resolvedReason = reason ?? summary;
    final deadlineAt = DateTime.now().add(const Duration(minutes: 2));

    sessionNotifier.setExecutionMetadata(
      runId: runId,
      phase: resolvedPhase,
      activeAgent: resolvedAgent,
      reason: resolvedReason,
    );

    if (status == 'completed' || status == 'failed') {
      _stalledRunHandled = false;
    }

    unawaited(
      runService.appendTrace(
        runId,
        AgentRunTrace(
          timestamp: DateTime.now(),
          source: source,
          target: target,
          type: type,
          summary: summary,
        ),
        status: status,
        phase: resolvedPhase,
        activeAgent: resolvedAgent,
        lastTransitionReason: resolvedReason,
        retryCount: retryCount,
        deadlineAt: deadlineAt,
        heartbeatAt: DateTime.now(),
        checkpoint: AgentRunCheckpoint(
          timestamp: DateTime.now(),
          phase: resolvedPhase,
          activeAgent: resolvedAgent ?? '',
          reason: resolvedReason,
          payloadSummary: summary,
        ),
      ),
    );
  }

  void dispose() {
    _subscription.cancel();
    _watchdogTimer?.cancel();
    for (var agent in _agents) {
      agent.dispose();
    }
    _agents.clear();
  }
}
