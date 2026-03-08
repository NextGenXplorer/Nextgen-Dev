import 'dart:async';
import '../models/agent_event.dart';

abstract class Agent {
  String get name;
  String get description;

  /// Defines what kinds of tasks this agent can handle.
  bool canHandle(AgentEvent event);

  /// Handle an incoming event targeted at this agent or broadcasted.
  Future<void> handleEvent(AgentEvent event);

  /// Called when the agent is being disposed/stopped.
  void dispose() {}
}
