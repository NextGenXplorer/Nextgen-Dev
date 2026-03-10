enum AgentEventType {
  taskAssigned,
  taskStarted,
  taskCompleted,
  taskFailed,
  message,
  error,
  deployRequested,
  agentStep,
}

class AgentEvent {
  final String sourceAgent;
  final String targetAgent;
  final AgentEventType type;
  final dynamic payload;
  final DateTime timestamp;

  AgentEvent({
    required this.sourceAgent,
    required this.targetAgent,
    required this.type,
    this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'AgentEvent(source: $sourceAgent, target: $targetAgent, type: $type, payload: $payload)';
  }
}
