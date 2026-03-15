import 'dart:async';
import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
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
You are an expert Debugger. A fatal crash or test failure has occurred in the application.
Error Trace:
$errorMessage

Your tasks:
1. Analyze the stack trace.
2. Use `<tool_call>{"name": "read_file", "path": "..."}</tool_call>` to inspect the files mentioned in the trace.
3. Determine the exact root cause of the crash.
4. Use `<tool_call>{"name": "edit_file", "path": "...", "target_text": "...", "replacement_text": "..."}</tool_call>` to fix the bug directly in the code.
5. Provide a summary of what you fixed.
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];

      final agentService = AgentService(
        provider: aiProvider,
        mode: 'Code',
        maxToolCalls: 10,
        workspaceManager: workspaceManager,
      );

      final completer = Completer<void>();

      agentService
          .run(history)
          .listen(
            (step) {
              bus.publish(
                AgentEvent(
                  sourceAgent: name,
                  targetAgent: 'System',
                  type: AgentEventType.agentStep,
                  payload: step,
                ),
              );
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
                  targetAgent: 'ReviewerAgent',
                  type: AgentEventType.taskAssigned,
                  payload: {
                    'originalTask': 'Verify fixes applied by DebuggerAgent',
                    'codeLog':
                        'DebuggerAgent analyzed the crash and applied fixes via edit_file. Please review to see if LGTM.',
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
