import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';

class ScaffolderAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;

  ScaffolderAgent({required this.bus, required this.aiProvider});

  @override
  String get name => 'ScaffolderAgent';

  @override
  String get description => 'A file system architect that generates boilerplate project structures.';

  @override
  bool canHandle(AgentEvent event) {
    return event.targetAgent == name && event.type == AgentEventType.taskAssigned;
  }

  @override
  Future<void> handleEvent(AgentEvent event) async {
    bus.publish(AgentEvent(
      sourceAgent: name,
      targetAgent: 'System',
      type: AgentEventType.message,
      payload: 'ScaffolderAgent is designing the file structure...',
    ));

    try {
      final payload = event.payload as Map<String, dynamic>;
      final originalTask = payload['originalTask'];
      final plan = payload['plan'];

      final prompt = '''
You are a file system architect. Given the following ProjectPlan, output a shell script that creates the project folder structure with boilerplate files.
Rules:
- Output ONLY a bash script. No commentary.
- Use 'mkdir -p' for directories and 'cat > file <<EOF' for file contents.
- Include realistic boilerplate: package.json, .gitignore, README.md, config files.
- Use placeholder comments like '# TODO: CoderAgent will fill this' in source files.
- The script must be idempotent (safe to re-run).

Original Task: $originalTask
Plan: $plan
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];
      final script = await aiProvider.generate(history);

      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'User',
        type: AgentEventType.message,
        payload: 'Scaffolding Script Generated:\\n$script',
      ));

      // Execute if we are on a platform that supports bash directly easily
      if (!Platform.isAndroid && !Platform.isIOS && !Platform.isWindows) {
        try {
          final result = await Process.run('bash', ['-c', script]);
          if (result.exitCode == 0) {
              bus.publish(AgentEvent(
                sourceAgent: name,
                targetAgent: 'System',
                type: AgentEventType.message,
                payload: 'Scaffolding applied successfully to filesystem.',
              ));
          } else {
             debugPrint('Scaffolding warning: \${result.stderr}');
          }
        } catch(e) {
             debugPrint('Scaffolding shell execution failed: \$e');
        }
      }

      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'CoderAgent',
        type: AgentEventType.taskAssigned,
        payload: {'originalTask': originalTask, 'plan': plan, 'scaffold': script},
      ));

      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'System',
        type: AgentEventType.taskCompleted,
        payload: 'Scaffolding phase complete. Handed off to CoderAgent.',
      ));

    } catch (e) {
      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'System',
        type: AgentEventType.taskFailed,
        payload: 'Failed to generate scaffold: $e',
      ));
    }
  }
}
