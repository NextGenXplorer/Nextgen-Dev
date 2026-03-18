import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../../domain/models/agent_handoff.dart';
import '../../domain/models/agent_step.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';
import '../../infrastructure/agent/agent_service.dart';
import '../../infrastructure/services/agent_memory_service.dart';
import '../../infrastructure/storage/workspace_manager.dart';

class PlannerAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;

  final WorkspaceManager workspaceManager;
  final AgentMemoryService memoryService;
  final String? Function()? projectPathProvider;
  PlannerAgent({
    required this.bus,
    required this.aiProvider,
    required this.workspaceManager,
    required this.memoryService,
    this.projectPathProvider,
  });

  @override
  String get name => 'PlannerAgent';

  @override
  String get description =>
      'Breaks down user requests into actionable implementation steps.';

  @override
  bool canHandle(AgentEvent event) {
    return event.targetAgent == name &&
        event.type == AgentEventType.taskAssigned;
  }

  @override
  Future<void> handleEvent(AgentEvent event) async {
    final payload = event.payload;
    String taskDescription;
    String? existingPlan;

    final normalizedPayload = AgentHandoff.unwrapData(payload);
    if (normalizedPayload is Map<String, dynamic>) {
      taskDescription = normalizedPayload['originalTask'] ?? '';
      existingPlan = normalizedPayload['plan'];
    } else {
      taskDescription = normalizedPayload.toString();
    }

    bus.publish(
      AgentEvent(
        sourceAgent: name,
        targetAgent: 'System',
        type: AgentEventType.message,
        payload: 'Planner is analyzing requirements...',
      ),
    );

    try {
      final prompt =
          '''
You are the ELITE PLANNER AGENT. Your goal is to architect a perfect, high-quality solution and ensure the user's coding request is clear and buildable by following a strict protocol:

1. DISCOVERY & CONTEXT PHASE: 
   - You MUST explore the current project state BEFORE planning.
   - Use `list_directory`, `get_project_context`, or `read_file` to understand the existing codebase intimately.
   - If the project is new, confirm the target directory is empty or appropriate.

2. REQUIREMENTS & DESIGN ANALYSIS:
   - Identify if the request is detailed enough. If vague, make professional, modern assumptions or ASK the user for specific details.
   - For UI/Frontend requests: Enforce premium aesthetics. The design MUST be modern (e.g., vibrant colors, dark mode, glassmorphism, responsive, animated). Specify these exact aesthetic constraints in the plan so the CoderAgent follows them. Generic UIs are forbidden.
   - For Backend/Logic requests: Enforce robust error handling, security, and type safety constraints in the plan.

3. STRUCTURED PLANNING:
   - Output a detailed, professional "# Implementation Plan".
   - MUST include a "## Architecture & Design" section detailing the approach and UI/UX standards.
   - MUST include a "## Proposed Directory Structure" block (using indented text).
   - MUST include a "## Technical Stack" section.
   - MUST include a "## Tasks" checklist (format: - [ ] Task description). Keep tasks modular.

4. CONTEXT:
   - Original Task: $taskDescription
   ${existingPlan != null ? "- Current Plan (to be refined): $existingPlan" : ""}

Do NOT start execution. Provide the plan and wait for the user's approval signal.
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];
      final agentService = AgentService(
        provider: aiProvider,
        mode: 'Agent',
        workspaceManager: workspaceManager,
        projectPathProvider: projectPathProvider,
        memoryService: memoryService,
      );
      String response = '';

      await for (final step in agentService.run(history)) {
        if (step.type == AgentStepType.toolCall) {
          bus.publish(
            AgentEvent(
              sourceAgent: name,
              targetAgent: 'System',
              type: AgentEventType.agentStep,
              payload: step,
            ),
          );
        } else if (step.type == AgentStepType.toolResult) {
          bus.publish(
            AgentEvent(
              sourceAgent: name,
              targetAgent: 'System',
              type: AgentEventType.agentStep,
              payload: step,
            ),
          );
        } else if (step.type == AgentStepType.text ||
            step.type == AgentStepType.finalAnswer) {
          response += step.content;
          bus.publish(
            AgentEvent(
              sourceAgent: name,
              targetAgent: 'User',
              type: AgentEventType.message,
              payload: step.content,
            ),
          );
        }
      }

      if (response.contains('# Implementation Plan')) {
        // We have a plan, notify that it's ready for approval
        bus.publish(
          AgentEvent(
            sourceAgent: name,
            targetAgent: 'User',
            type: AgentEventType.planReady,
            payload: AgentHandoff(
              status: 'completed',
              reason: 'Implementation plan is ready for approval.',
              artifacts: ['implementation_plan'],
              evidence: ['PlannerAgent produced a # Implementation Plan.'],
              nextRecommendedAgent: 'User',
              data: {'originalTask': taskDescription, 'plan': response},
            ).toJson(),
          ),
        );
      } else {
        // It's likely a request for more info or a conversational response
        bus.publish(
          AgentEvent(
            sourceAgent: name,
            targetAgent: 'System',
            type: AgentEventType.taskCompleted,
            payload: AgentHandoff(
              status: 'completed',
              reason: 'Planner finished conversation/questioning phase.',
              evidence: ['PlannerAgent responded without producing a plan.'],
              nextRecommendedAgent: 'User',
            ).toJson(),
          ),
        );
      }
    } catch (e) {
      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskFailed,
          payload: AgentHandoff(
            status: 'failed',
            reason: 'Failed in planning phase: $e',
            evidence: ['PlannerAgent threw an exception during planning.'],
            nextRecommendedAgent: 'SupervisorAgent',
          ).toJson(),
        ),
      );
    }
  }
}
