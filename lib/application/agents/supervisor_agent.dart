import 'dart:convert';

import '../../domain/interfaces/agent.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/agent_event.dart';
import '../../domain/models/agent_handoff.dart';
import '../../domain/models/chat_message.dart';
import '../../infrastructure/services/agent_memory_service.dart';
import '../agent_bus.dart';

class SupervisorAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;
  final AgentMemoryService memoryService;
  final String? Function()? projectPathProvider;

  SupervisorAgent({
    required this.bus,
    required this.aiProvider,
    required this.memoryService,
    this.projectPathProvider,
  });

  @override
  String get name => 'SupervisorAgent';

  @override
  String get description =>
      'Supervises workflow health, detects bad branches, and decides whether to debug or re-plan.';

  @override
  bool canHandle(AgentEvent event) =>
      event.targetAgent == name &&
      (event.type == AgentEventType.taskAssigned ||
          event.type == AgentEventType.error);

  @override
  Future<void> handleEvent(AgentEvent event) async {
    try {
      final normalizedPayload = AgentHandoff.unwrapData(event.payload);
      final context = normalizedPayload is Map<String, dynamic>
          ? Map<String, dynamic>.from(normalizedPayload)
          : <String, dynamic>{'context': AgentHandoff.summarize(event.payload)};

      final prompt = '''
You are the SupervisorAgent for an autonomous coding workflow.
Your job is to choose the next recovery branch.

${await memoryService.buildExecutionContext(
        task: context.toString(),
        projectPath: projectPathProvider?.call(),
        agentName: name,
      )}

Allowed target agents:
- DebuggerAgent -> use for concrete implementation/runtime/build/test errors that should be fixed directly.
- PlannerAgent -> use for repeated failures, architectural mismatch, vague requirements, or when the workflow needs a fresh plan.

Decision rules:
- Prefer DebuggerAgent for first-pass build/test/runtime failures.
- Prefer PlannerAgent when retries are piling up, the branch appears wrong, or the implementation likely needs re-planning.
- Return strict JSON only.

Schema:
{"targetAgent":"DebuggerAgent|PlannerAgent","reason":"short string","handoff":"string"}

Context:
${context.toString()}
''';

      final raw = (await aiProvider.generate([
        ChatMessage(role: MessageRole.user, content: prompt),
      ])).trim();

      final decision = _parseDecision(raw);
      final targetAgent = decision.targetAgent;
      final reason = decision.reason;
      final handoff = decision.handoff;

      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'User',
          type: AgentEventType.message,
          payload: 'Supervisor decision → $targetAgent: $reason',
        ),
      );

      if (targetAgent == 'PlannerAgent') {
        bus.publish(
          AgentEvent(
            sourceAgent: name,
            targetAgent: 'PlannerAgent',
            type: AgentEventType.taskAssigned,
            payload: AgentHandoff(
              status: 'redirected',
              reason: reason,
              artifacts: ['supervisor_decision'],
              evidence: [handoff],
              nextRecommendedAgent: 'PlannerAgent',
              data: {
                'originalTask': context['failure']?.toString() ?? 'Recovery plan',
                'plan': handoff,
              },
            ).toJson(),
          ),
        );
      } else {
        bus.publish(
          AgentEvent(
            sourceAgent: name,
            targetAgent: 'DebuggerAgent',
            type: AgentEventType.error,
            payload: AgentHandoff(
              status: 'redirected',
              reason: reason,
              artifacts: ['supervisor_decision'],
              evidence: [handoff],
              nextRecommendedAgent: 'DebuggerAgent',
              data: {
                'failure': handoff,
                'sourceAgent': context['sourceAgent']?.toString() ?? name,
              },
            ).toJson(),
          ),
        );
      }
    } catch (e) {
      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'DebuggerAgent',
          type: AgentEventType.error,
          payload: AgentHandoff(
            status: 'failed',
            reason:
                'Supervisor fallback: automatic recovery routing due to supervisor error: $e',
            evidence: ['SupervisorAgent exception fallback triggered.'],
            nextRecommendedAgent: 'DebuggerAgent',
            data: {
              'failure':
                  'Supervisor fallback: automatic recovery routing due to supervisor error: $e',
              'sourceAgent': name,
            },
          ).toJson(),
        ),
      );
    }
  }

  _SupervisorDecision _parseDecision(String raw) {
    try {
      final cleaned = raw
          .replaceAll(RegExp(r'^```json\s*'), '')
          .replaceAll(RegExp(r'^```\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '')
          .trim();
      final json = cleaned.startsWith('{')
          ? cleaned
          : '{"targetAgent":"DebuggerAgent","reason":"Fallback to debugger","handoff":${_jsonEscape(raw)}}';
      final decoded = Map<String, dynamic>.from(
        jsonDecode(json) as Map<String, dynamic>,
      );
      final target = decoded['targetAgent']?.toString() ?? 'DebuggerAgent';
      return _SupervisorDecision(
        targetAgent: target == 'PlannerAgent' ? 'PlannerAgent' : 'DebuggerAgent',
        reason: decoded['reason']?.toString() ?? 'Fallback to debugger',
        handoff: decoded['handoff']?.toString() ?? raw,
      );
    } catch (_) {
      return _SupervisorDecision(
        targetAgent: 'DebuggerAgent',
        reason: 'Fallback to debugger',
        handoff: raw,
      );
    }
  }

  String _jsonEscape(String input) =>
      '"${input.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n')}"';
}

class _SupervisorDecision {
  final String targetAgent;
  final String reason;
  final String handoff;

  const _SupervisorDecision({
    required this.targetAgent,
    required this.reason,
    required this.handoff,
  });
}
