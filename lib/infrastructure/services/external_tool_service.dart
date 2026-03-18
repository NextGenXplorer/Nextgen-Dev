import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'agent_permission_service.dart';

final externalToolServiceProvider = Provider<ExternalToolService>((ref) {
  return ExternalToolService();
});

class ExternalToolDefinition {
  final String id;
  final String name;
  final String type;
  final String endpoint;
  final Map<String, String> headers;
  final List<String> environments;
  final String? credentialScope;
  final List<String> allowedActions;

  const ExternalToolDefinition({
    required this.id,
    required this.name,
    required this.type,
    required this.endpoint,
    this.headers = const {},
    this.environments = const ['network'],
    this.credentialScope,
    this.allowedActions = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'endpoint': endpoint,
    'headers': headers,
    'environments': environments,
    'credentialScope': credentialScope,
    'allowedActions': allowedActions,
  };

  factory ExternalToolDefinition.fromJson(Map<String, dynamic> json) {
    final rawHeaders = json['headers'];
    return ExternalToolDefinition(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'connector',
      endpoint: json['endpoint'] as String? ?? '',
      headers: rawHeaders is Map
          ? rawHeaders.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
      environments: json['environments'] is List
          ? (json['environments'] as List)
              .map((item) => item.toString())
              .toList()
          : const ['network'],
      credentialScope: json['credentialScope']?.toString(),
      allowedActions: json['allowedActions'] is List
          ? (json['allowedActions'] as List)
              .map((item) => item.toString())
              .toList()
          : const [],
    );
  }
}

class ExternalToolService {
  static const String _prefsKey = 'external_tool_definitions';
  final AgentPermissionService permissionService;

  ExternalToolService({AgentPermissionService? permissionService})
      : permissionService = permissionService ?? AgentPermissionService();

  Future<List<ExternalToolDefinition>> loadDefinitions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    return raw
        .map((entry) {
          try {
            return ExternalToolDefinition.fromJson(
              jsonDecode(entry) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<ExternalToolDefinition>()
        .toList();
  }

  Future<String> listToolsSummary() async {
    final tools = await loadDefinitions();
    if (tools.isEmpty) {
      return 'No external tools are configured. Add MCP/connector endpoints to SharedPreferences key "$_prefsKey" to enable them.';
    }

    return tools
        .map(
          (tool) =>
              '- ${tool.name} [${tool.id}] (${tool.type}) -> ${tool.endpoint}',
        )
        .join('\n');
  }

  Future<String> invokeTool({
    required String toolId,
    String? action,
    Map<String, dynamic>? payload,
    String environment = 'network',
    String? credentialScope,
  }) async {
    final tools = await loadDefinitions();
    ExternalToolDefinition? tool;
    for (final candidate in tools) {
      if (candidate.id == toolId) {
        tool = candidate;
        break;
      }
    }

    if (tool == null) {
      return 'Error: External tool "$toolId" is not configured.';
    }
    if (!tool.environments.contains(environment)) {
      return 'Error: External tool "$toolId" is not allowed in environment "$environment".';
    }
    if (tool.allowedActions.isNotEmpty &&
        action != null &&
        action.isNotEmpty &&
        !tool.allowedActions.contains(action)) {
      return 'Error: Action "$action" is not allowed for external tool "$toolId".';
    }

    final resolvedScope = credentialScope ?? tool.credentialScope;
    final scopedHeaders = resolvedScope == null || resolvedScope.isEmpty
        ? const <String, String>{}
        : await permissionService.resolveScopedHeaders(
            scope: resolvedScope,
            environment: environment,
          );
    if (resolvedScope != null &&
        resolvedScope.isNotEmpty &&
        scopedHeaders.isEmpty) {
      return 'Error: No scoped credential is configured for scope "$resolvedScope" in environment "$environment".';
    }

    final body = {
      'tool_id': tool.id,
      if (action != null && action.isNotEmpty) 'action': action,
      'environment': environment,
      'payload': payload ?? <String, dynamic>{},
    };

    try {
      final response = await http.post(
        Uri.parse(tool.endpoint),
        headers: {
          'Content-Type': 'application/json',
          ...tool.headers,
          ...scopedHeaders,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body;
      }
      return 'Error: External tool call failed (${response.statusCode}): ${response.body}';
    } catch (e) {
      return 'Error: Failed to call external tool "$toolId": $e';
    }
  }
}
