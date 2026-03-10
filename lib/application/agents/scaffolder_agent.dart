import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../domain/interfaces/agent.dart';
import '../../domain/models/agent_event.dart';
import '../../domain/models/agent_step.dart';
import '../agent_bus.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../domain/models/chat_message.dart';
import '../../infrastructure/agent/agent_service.dart';

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
You are the Scaffolder Agent in a multi-agent system.
Your job is to generate boilerplate project structures.
Use the `build_project` tool to create the base directories and files.
Use `run_terminal_command` for any initial setup commands (e.g. pub get, npm install).

Original Task: $originalTask
Plan: $plan
''';

      final history = [ChatMessage(role: MessageRole.user, content: prompt)];
      final agentService = AgentService(provider: aiProvider, mode: 'Agent');
      
      String scaffoldLog = '';
      
      await for (final step in agentService.run(history)) {
         if (step.type == AgentStepType.toolCall) {
            bus.publish(AgentEvent(sourceAgent: name, targetAgent: 'User', type: AgentEventType.message, payload: 'Tool Call: ${step.content}'));
         } else if (step.type == AgentStepType.toolResult) {
            bus.publish(AgentEvent(sourceAgent: name, targetAgent: 'User', type: AgentEventType.message, payload: 'Tool Result: \\n${step.content}'));
         } else if (step.type == AgentStepType.text || step.type == AgentStepType.finalAnswer) {
            scaffoldLog += step.content;
            bus.publish(AgentEvent(sourceAgent: name, targetAgent: 'User', type: AgentEventType.message, payload: step.content));
         }
      }

      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'User',
        type: AgentEventType.message,
        payload: 'The Scaffolder Agent has completed the internal file structure.',
      ));

      bus.publish(AgentEvent(
        sourceAgent: name,
        targetAgent: 'CoderAgent',
        type: AgentEventType.taskAssigned,
        payload: {'originalTask': originalTask, 'plan': plan, 'scaffoldLog': scaffoldLog},
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
