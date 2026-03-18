import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../../domain/models/agent_step.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';
import '../../infrastructure/agent/agent_service.dart';
import '../../infrastructure/storage/workspace_manager.dart';

class ScaffolderAgent extends Agent {
  final AgentBus bus;
  final AIProvider aiProvider;

  final WorkspaceManager workspaceManager;
  ScaffolderAgent({
    required this.bus,
    required this.aiProvider,
    required this.workspaceManager,
  });

  @override
  String get name => 'ScaffolderAgent';

  @override
  String get description =>
      'A file system architect that generates boilerplate project structures.';

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
        payload: '🏗️ ScaffolderAgent is designing the file structure...',
      ),
    );

    try {
      final payload = event.payload as Map<String, dynamic>;
      final originalTask = payload['originalTask'];
      final plan = payload['plan'];

      final prompt =
          '''
You are the ELITE SCAFFOLDER AGENT. Your job is to strictly turn a Master "# Implementation Plan" into a physical, production-ready directory structure.

1. EXTRACT STRUCTURE: Carefully analyze the "## Proposed Directory Structure" in the Master Plan.
2. EXECUTE ELITE SCAFFOLD: 
   - Use `build_project` to create the architectural skeleton.
   - Use latest, mobile-compatible libraries and patterns.
   - Files MUST include high-quality boilerplate:
     - Clear README.md with project goals.
     - Clean, modular entry points (e.g., main.dart, index.html).
     - Proper configuration for styling (CSS variables, theme files).
3. ENVIRONMENT SETUP:
   - Run necessary non-interactive terminal commands (`flutter create .`, `npm init -y`) to initialize the environment.
   - Ensure you are working in a clean state.

Master Plan: $plan
Original Task: $originalTask
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];
      final agentService = AgentService(
        provider: aiProvider,
        mode: 'Agent',
        workspaceManager: workspaceManager,
      );

      String scaffoldLog = '';

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
          scaffoldLog += step.content;
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
          payload:
              'The Scaffolder Agent has completed the internal file structure.',
        ),
      );

      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'CoderAgent',
          type: AgentEventType.taskAssigned,
          payload: {
            'originalTask': originalTask,
            'plan': plan,
            'scaffoldLog': scaffoldLog,
          },
        ),
      );

      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskCompleted,
          payload: 'Scaffolding phase complete. Handed off to CoderAgent.',
        ),
      );
    } catch (e) {
      bus.publish(
        AgentEvent(
          sourceAgent: name,
          targetAgent: 'System',
          type: AgentEventType.taskFailed,
          payload: 'Failed to generate scaffold: $e',
        ),
      );
    }
  }
}
