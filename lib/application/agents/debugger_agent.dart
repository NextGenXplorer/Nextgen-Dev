import 'dart:async';
import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../../domain/models/agent_step.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';
import '../../infrastructure/agent/agent_service.dart';
import '../../infrastructure/storage/workspace_manager.dart';

class DebuggerAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;

  final WorkspaceManager workspaceManager;
  DebuggerAgent({
    required this.bus,
    required this.aiProvider,
    required this.workspaceManager,
  });

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
    bus.publish(
      AgentEvent(
        sourceAgent: name,
        targetAgent: 'System',
        type: AgentEventType.message,
        payload: 'DebuggerAgent analyzing error...',
      ),
    );

    try {
      final errorMessage = event.payload.toString();

      final prompt =
          '''
You are an AUTONOMOUS SOLVER AGENT — an elite debugger who operates at the level of a senior staff engineer. A crash or build failure has occurred. Fix it completely without asking the user for guidance.

════ WORKFLOW ORCHESTRATION ════

### 1. Plan Mode
- Before touching any file: write a brief analysis of the error and your intended fix strategy.
- If your initial diagnosis is wrong: STOP, re-read the logs, re-plan.

### 2. Subagent Strategy (Focused Execution)
- ONE tool call per step. No bulk edits.
- Use `read_file` for every file mentioned in the stack trace before attempting a fix.

### 3. Self-Improvement Loop
- After each fix, note the pattern: "Lesson: [Root cause | Never do X because Y]".
- Carry this lesson forward to avoid repeating the same class of errors.

### 4. Verification Before Done (MANDATORY)
- After applying the fix: run the SAME command that produced the error.
- Iterate the fix/verify loop until exit code is 0.
- NEVER report success without proof of a passing build/test.

### 5. Demand Elegance
- Apply the most minimal, surgical fix possible. No unnecessary refactors.
- If the obvious fix feels hacky, ask: "What is the elegant, root-cause solution?"

### 6. Autonomous Bug Fixing
- No hand-holding. No asking for clarification.
- Read the error → trace root cause → apply fix → verify → report done.

════ ERROR REPORT ════
$errorMessage

Zero context switching from the user. Fix it. Prove it works. Report done.
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];

      final agentService = AgentService(
        provider: aiProvider,
        mode: 'Agent',
        maxToolCalls: 40,
        workspaceManager: workspaceManager,
      );

      final completer = Completer<void>();

      agentService
          .run(history)
          .listen(
            (step) {
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
                bus.publish(
                  AgentEvent(
                    sourceAgent: name,
                    targetAgent: 'User',
                    type: AgentEventType.message,
                    payload: step.content,
                  ),
                );
              }
            },
            onDone: () {
              bus.publish(
                AgentEvent(
                  sourceAgent: name,
                  targetAgent: 'System',
                  type: AgentEventType.taskCompleted,
                  payload: 'Debugging and autofix complete.',
                ),
              );
              // Route back to the ReviewerAgent to verify the fixes and potentially trigger the preview
              bus.publish(
                AgentEvent(
                  sourceAgent: name,
                  targetAgent: 'TestingAgent',
                  type: AgentEventType.taskAssigned,
                  payload: {
                    'originalTask': 'Verify fixes applied by DebuggerAgent',
                    'codeLog':
                        'DebuggerAgent analyzed the crash and applied fixes via edit_file. Please review to see if PASSED.',
                  },
                ),
              );
              completer.complete();
            },
            onError: (e) {
              bus.publish(
                AgentEvent(
                  sourceAgent: name,
                  targetAgent: 'System',
                  type: AgentEventType.taskFailed,
                  payload: 'Debugger failed during agent streaming: $e',
                ),
              );
              completer.complete();
            },
          );

      await completer.future;
    } catch (e) {
      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskFailed,
          payload: 'Debugger failed to analyze error: $e',
        ),
      );
    }
  }
}
