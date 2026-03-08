/// Base interface all agent tools must implement
abstract class AgentTool {
  /// Short identifier used in tool_call tags
  String get name;

  /// Human-readable description shown in UI during tool call
  String get displayName;

  /// Icon name for the UI
  String get uiIcon; // 'search' | 'link' | 'code'

  /// Description injected into the system prompt
  String get description;

  /// Execute and return a string result to feed back to the AI
  Future<String> execute(Map<String, dynamic> params);
}
