import 'package:flutter/foundation.dart';

/// Represents a tool that the Agentic LLM can call.
/// This acts as the schema definition sent to the AI, and the executable
/// logic bridging the AI action to the native/PRoot layer.
abstract class AgentTool {
  /// The exact name of the tool as it will appear in the AI's system prompt (e.g., 'read_file').
  String get name;

  /// A detailed description of what the tool does and when the AI should use it.
  String get description;

  /// JSON Schema definition of the expected arguments.
  /// Example:
  /// {
  ///   "type": "object",
  ///   "properties": {
  ///     "path": { "type": "string", "description": "Absolute file path" }
  ///   },
  ///   "required": ["path"]
  /// }
  Map<String, dynamic> get parameters;

  /// Extracts the required parameters from the raw JSON arguments and
  /// executes the native or PRoot action.
  /// Returns the observation (output) as a string to be appended to the LLM context.
  Future<String> execute(Map<String, dynamic> arguments);

  @override
  String toString() => 'AgentTool($name)';
}
