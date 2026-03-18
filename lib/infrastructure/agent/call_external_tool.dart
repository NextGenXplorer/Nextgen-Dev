import '../services/external_tool_service.dart';
import 'agent_tool.dart';

class CallExternalTool implements AgentTool {
  final ExternalToolService service;

  CallExternalTool(this.service);

  @override
  String get name => 'call_external_tool';

  @override
  String get displayName => 'Call External Tool';

  @override
  String get uiIcon => 'hub';

  @override
  String get description =>
      'Calls a configured external MCP/connector-style tool endpoint with a JSON payload.';

  @override
  Future<String> execute(Map<String, dynamic> params) {
    final toolId = params['tool_id'] as String?;
    final action = params['action'] as String?;
    final environment = params['environment']?.toString() ?? 'network';
    final credentialScope = params['credential_scope']?.toString();
    final payload = params['payload'] is Map
        ? Map<String, dynamic>.from(params['payload'] as Map)
        : <String, dynamic>{};

    if (toolId == null || toolId.trim().isEmpty) {
      return Future.value('Error: tool_id is required.');
    }

    return service.invokeTool(
      toolId: toolId,
      action: action,
      payload: payload,
      environment: environment,
      credentialScope: credentialScope,
    );
  }
}
