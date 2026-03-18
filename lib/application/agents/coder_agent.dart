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

class CoderAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;

  final WorkspaceManager workspaceManager;
  final AgentMemoryService memoryService;
  final String? Function()? projectPathProvider;
  CoderAgent({
    required this.bus,
    required this.aiProvider,
    required this.workspaceManager,
    required this.memoryService,
    this.projectPathProvider,
  });

  @override
  String get name => 'CoderAgent';

  @override
  String get description =>
      'Generates code and shell commands based on a provided plan.';

  @override
  bool canHandle(AgentEvent event) {
    return event.targetAgent == name &&
        event.type == AgentEventType.taskAssigned;
  }

  @override
  Future<void> handleEvent(AgentEvent event) async {
    bus.publish(
      AgentEvent(
        sourceAgent: name,
        targetAgent: 'User',
        type: AgentEventType.message,
        payload: '⚡ CoderAgent is generating implementation...',
      ),
    );

    try {
      final payload =
          AgentHandoff.unwrapData(event.payload) as Map<String, dynamic>;
      final originalTask = payload['originalTask'];
      final plan = payload['plan'];
      final scaffoldLog = payload['scaffoldLog'] ?? '';

      final prompt =
          '''
You are the ELITE CODER AGENT — operating at the level of a top 1% staff engineer at a world-leading tech company.

════ WORKFLOW ORCHESTRATION ════

### 1. Plan Mode Default
- For each major component: briefly state your implementation approach BEFORE writing code.
- If something goes wrong mid-build: STOP, re-analyze, and re-plan.
- Write complete, production-ready code. Never use stubs or TODOs.

### 2. Subagent Strategy (Focused Execution)
- ONE tool call per step. Never do multiple file edits in a single response.
- Use `list_directory` and `read_file` to explore before any edits.
- Use `run_terminal_command` for package installs, builds, and verifications.

### 3. Self-Improvement Loop
- After ANY error: briefly note what caused it and the fix pattern: "Lesson: [never do X because Y]".
- Apply this pattern going forward in the same session to avoid repeating the mistake.

### 4. Verification Before Done (MANDATORY)
- NEVER emit TASK_UPDATE: [/] -> [x] without FIRST running a verification command.
- For Flutter/Dart: run `dart_analyzer` and `flutter analyze`.
- For Web: run `npm run build` or `npx tsc --noEmit`.
- If errors are found, fix them immediately — loop until the build/test PASSES.
- Ask yourself: "Would a senior staff engineer approve this without a second thought?"

### 5. Demand Elegance (Balanced Quality)
- For non-trivial features: pause and ask: "Is there a more elegant structure or pattern here?"
- If a solution feels hacky, implement the clean one instead.
- Skip this for obvious one-line fixes.

### 6. Autonomous Bug Fixing
- When encountering errors after running a build: do NOT stop or ask for help.
- Read the error message → trace the root cause → apply the minimal surgical fix → re-verify.
- Zero context switching from the user.

════ CODE STANDARDS ════
- Premium UI: harmonized HSL colors, Inter/Outfit/Roboto fonts, glassmorphism, smooth animations.
- Modern libraries only. No deprecated APIs. OWASP secure patterns.
- Track every sub-task: TASK_UPDATE: [ ] -> [/] Task Name, then TASK_UPDATE: [/] -> [x] Task Name.
- Follow the Plan's directory structure EXACTLY.

Original Task: $originalTask
Master Plan: $plan
Scaffolding Context: $scaffoldLog
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];
      final agentService = AgentService(
        provider: aiProvider,
        mode: 'Agent',
        maxToolCalls: 80, // Complex builds need many build/verify/fix loops
        workspaceManager: workspaceManager,
        projectPathProvider: projectPathProvider,
        memoryService: memoryService,
      );

      String codeLog = '';

      await for (final step in agentService.run(history)) {
        if (step.type == AgentStepType.toolCall ||
            step.type == AgentStepType.toolResult) {
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
          codeLog += step.content;
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

      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'User',
          type: AgentEventType.message,
          payload: 'The Coder Agent has completed the implementation phase.',
        ),
      );

      // Hand off code to TestingAgent for automated verification
      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'TestingAgent',
          type: AgentEventType.taskAssigned,
          payload: AgentHandoff(
            status: 'completed',
            reason: 'Implementation is ready for verification.',
            artifacts: ['implementation_log'],
            evidence: ['CoderAgent completed code generation.'],
            nextRecommendedAgent: 'TestingAgent',
            data: {'originalTask': originalTask, 'codeLog': codeLog},
          ).toJson(),
        ),
      );

      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskCompleted,
          payload: AgentHandoff(
            status: 'completed',
            reason:
                'Coding phase complete. Handed off to TestingAgent for verification.',
            artifacts: ['implementation_log'],
            evidence: ['Generated implementation log for testing.'],
            nextRecommendedAgent: 'TestingAgent',
          ).toJson(),
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
            reason: 'Failed to generate code: $e',
            evidence: ['CoderAgent threw an exception while generating code.'],
            nextRecommendedAgent: 'SupervisorAgent',
          ).toJson(),
        ),
      );
    }
  }
}
