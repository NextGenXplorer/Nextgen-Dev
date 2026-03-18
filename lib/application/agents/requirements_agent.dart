import 'dart:convert';

import '../../domain/interfaces/agent.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/agent_event.dart';
import '../../domain/models/agent_handoff.dart';
import '../../domain/models/chat_message.dart';
import '../../infrastructure/services/agent_memory_service.dart';
import '../agent_bus.dart';

class RequirementsAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;
  final AgentMemoryService memoryService;
  final String? Function()? projectPathProvider;

  RequirementsAgent({
    required this.bus,
    required this.aiProvider,
    required this.memoryService,
    required dynamic workspaceManager,
    this.projectPathProvider,
  });

  @override
  String get name => 'RequirementsAgent';

  @override
  String get description =>
      'Clarifies ambiguous requests, captures constraints, and hands a concrete brief to planning.';

  @override
  bool canHandle(AgentEvent event) =>
      event.targetAgent == name && event.type == AgentEventType.taskAssigned;

  @override
  Future<void> handleEvent(AgentEvent event) async {
    try {
      final payload = event.payload;
      final normalizedPayload = AgentHandoff.unwrapData(payload);
      if (normalizedPayload is Map<String, dynamic> &&
          normalizedPayload['followUp'] != null) {
        await _handleFollowUp(
          originalTask: normalizedPayload['originalTask']?.toString() ?? '',
          userAnswer: normalizedPayload['followUp']?.toString() ?? '',
        );
        return;
      }

      final originalTask = normalizedPayload is Map<String, dynamic>
          ? normalizedPayload['task']?.toString() ?? ''
          : normalizedPayload?.toString() ?? '';
      final response = await _analyzeTask(originalTask);

      if (response.question != null && response.question!.isNotEmpty) {
        bus.publish(
          AgentEvent(
            sourceAgent: name,
            targetAgent: 'User',
            type: AgentEventType.message,
            payload: response.question!,
          ),
        );
        bus.publish(
          AgentEvent(
            sourceAgent: name,
            targetAgent: 'System',
            type: AgentEventType.awaitingRequirements,
            payload: AgentHandoff(
              status: 'needs_input',
              reason: 'RequirementsAgent needs one clarification from the user.',
              artifacts: ['requirements_question'],
              evidence: [response.question ?? ''],
              nextRecommendedAgent: 'User',
              data: {'originalTask': originalTask},
            ).toJson(),
          ),
        );
        return;
      }

      final gathered = response.brief?.trim().isNotEmpty == true
          ? response.brief!.trim()
          : _defaultBrief(originalTask);
      _publishRequirementsGathered(originalTask, gathered);
    } catch (e) {
      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskFailed,
          payload: AgentHandoff(
            status: 'failed',
            reason: 'Failed during requirements gathering: $e',
            evidence: [
              'RequirementsAgent threw an exception during clarification.'
            ],
            nextRecommendedAgent: 'SupervisorAgent',
          ).toJson(),
        ),
      );
    }
  }

  Future<void> _handleFollowUp({
    required String originalTask,
    required String userAnswer,
  }) async {
    final memoryContext = await memoryService.buildExecutionContext(
      task: '$originalTask\n$userAnswer',
      projectPath: projectPathProvider?.call(),
      agentName: name,
    );
    final mergedPrompt = '''
You are the RequirementsAgent for NextGen IDE.
Combine the original task and the user's follow-up into a concise implementation brief.

$memoryContext

Return strict JSON:
{"brief":"..."}

Original task:
$originalTask

User follow-up:
$userAnswer
''';

    final response = (await aiProvider.generate([
      ChatMessage(role: MessageRole.user, content: mergedPrompt),
    ])).trim();

    String brief;
    try {
      final decoded = jsonDecode(response) as Map<String, dynamic>;
      brief = decoded['brief']?.toString().trim() ?? '';
    } catch (_) {
      brief = response;
    }

    _publishRequirementsGathered(
      originalTask,
      brief.isNotEmpty ? brief : _defaultBrief('$originalTask\n$userAnswer'),
    );
  }

  Future<_RequirementsResponse> _analyzeTask(String task) async {
    final prompt = '''
You are the RequirementsAgent for an autonomous coding IDE.
Your job is to decide whether the task is actionable as-is or if exactly one high-value clarification question is required.

${await memoryService.buildExecutionContext(
      task: task,
      projectPath: projectPathProvider?.call(),
      agentName: name,
    )}

Rules:
- Prefer moving forward with strong professional defaults.
- Ask a question only if the answer would materially change architecture, stack, or deliverables.
- If the task is actionable, produce a concise brief with assumptions and success criteria.
- Return strict JSON only.

JSON schema:
{"status":"ready|needs_input","question":"string or empty","brief":"string or empty"}

Task:
$task
''';

    final raw = (await aiProvider.generate([
      ChatMessage(role: MessageRole.user, content: prompt),
    ])).trim();

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return _RequirementsResponse(
        status: decoded['status']?.toString() ?? 'ready',
        question: decoded['question']?.toString(),
        brief: decoded['brief']?.toString(),
      );
    } catch (_) {
      return _RequirementsResponse(
        status: 'ready',
        brief: raw.isNotEmpty ? raw : _defaultBrief(task),
      );
    }
  }

  void _publishRequirementsGathered(String originalTask, String gathered) {
    bus.publish(
      AgentEvent(
        sourceAgent: name,
        targetAgent: 'User',
        type: AgentEventType.message,
        payload: 'Requirements locked in. Handing off to planning...',
      ),
    );
    bus.publish(
      AgentEvent(
        sourceAgent: name,
        targetAgent: 'System',
        type: AgentEventType.requirementsGathered,
        payload: AgentHandoff(
          status: 'completed',
          reason: 'Requirements were clarified and are ready for planning.',
          artifacts: ['requirements_brief'],
          evidence: [gathered],
          nextRecommendedAgent: 'PlannerAgent',
          data: {
            'originalTask': originalTask,
            'gatheredRequirements': gathered,
          },
        ).toJson(),
      ),
    );
  }

  String _defaultBrief(String task) => '''
Implementation brief:
- Fulfill the user's request end-to-end.
- Use modern, production-ready architecture and UX defaults.
- Validate the finished result with the appropriate analyzer/build/test command before declaring success.
- Avoid placeholders, TODOs, and incomplete flows.

Task:
$task
''';
}

class _RequirementsResponse {
  final String status;
  final String? question;
  final String? brief;

  const _RequirementsResponse({
    required this.status,
    this.question,
    this.brief,
  });
}
