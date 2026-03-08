/// Represents one visible step the agent took (shown inline in chat)
enum AgentStepType { toolCall, toolResult, text, finalAnswer }

class AgentStep {
  final AgentStepType type;
  final String content;
  final String? toolName;
  final Map<String, dynamic>? toolParams;

  const AgentStep({
    required this.type,
    required this.content,
    this.toolName,
    this.toolParams,
  });
}
