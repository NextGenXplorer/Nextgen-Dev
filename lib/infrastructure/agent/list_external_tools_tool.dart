import '../services/external_tool_service.dart';
import 'agent_tool.dart';

class ListExternalToolsTool implements AgentTool {
  final ExternalToolService service;

  ListExternalToolsTool(this.service);

  @override
  String get name => 'list_external_tools';

  @override
  String get displayName => 'List External Tools';

  @override
  String get uiIcon => 'extension';

  @override
  String get description =>
      'Lists configured external MCP/connector-style tools available to the agent.';

  @override
  Future<String> execute(Map<String, dynamic> params) {
    return service.listToolsSummary();
  }
}
