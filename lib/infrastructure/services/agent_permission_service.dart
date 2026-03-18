import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/tool_audit_entry.dart';

final agentPermissionServiceProvider = Provider<AgentPermissionService>((ref) {
  return AgentPermissionService();
});

class ToolPermissionDecision {
  final bool allowed;
  final bool requiresConfirmation;
  final String approvalMode;
  final String environment;
  final String reason;

  const ToolPermissionDecision({
    required this.allowed,
    required this.requiresConfirmation,
    required this.approvalMode,
    required this.environment,
    required this.reason,
  });
}

class ScopedCredential {
  final String id;
  final String headerName;
  final String value;
  final List<String> scopes;
  final List<String> environments;

  const ScopedCredential({
    required this.id,
    required this.headerName,
    required this.value,
    this.scopes = const [],
    this.environments = const [],
  });

  factory ScopedCredential.fromJson(Map<String, dynamic> json) {
    List<String> toList(dynamic raw) => raw is List
        ? raw.map((item) => item.toString()).toList()
        : const [];
    return ScopedCredential(
      id: json['id']?.toString() ?? '',
      headerName: json['headerName']?.toString() ?? 'Authorization',
      value: json['value']?.toString() ?? '',
      scopes: toList(json['scopes']),
      environments: toList(json['environments']),
    );
  }
}

class AgentPermissionService {
  static const _auditPrefsKey = 'agent_tool_audit_log_v1';
  static const _credentialPrefsKey = 'scoped_credentials_v1';
  static const _maxAuditEntries = 400;

  static const Map<String, String> _defaultApprovalModes = {
    'read_file': 'auto',
    'list_directory': 'auto',
    'search_files': 'auto',
    'web_search': 'auto',
    'read_url': 'auto',
    'list_projects': 'auto',
    'get_project_context': 'auto',
    'list_benchmarks': 'auto',
    'evaluate_run': 'auto',
    'list_external_tools': 'auto',
    'dart_analyzer': 'auto',
    'take_screenshot': 'auto',
    'create_file': 'auto',
    'edit_file': 'auto',
    'build_project': 'auto',
    'install_package': 'auto',
    'run_terminal_command': 'manual_for_destructive',
    'git': 'manual_for_destructive',
    'call_external_tool': 'scoped',
  };

  static const Map<String, List<String>> _allowedEnvironments = {
    'read_file': ['workspace', 'sandbox'],
    'list_directory': ['workspace', 'sandbox'],
    'search_files': ['workspace', 'sandbox'],
    'web_search': ['network'],
    'read_url': ['network'],
    'list_projects': ['workspace'],
    'get_project_context': ['workspace'],
    'list_benchmarks': ['workspace'],
    'evaluate_run': ['workspace'],
    'list_external_tools': ['workspace'],
    'dart_analyzer': ['workspace', 'sandbox'],
    'take_screenshot': ['workspace'],
    'create_file': ['workspace', 'sandbox'],
    'edit_file': ['workspace', 'sandbox'],
    'build_project': ['workspace', 'sandbox'],
    'install_package': ['workspace', 'sandbox'],
    'run_terminal_command': ['workspace', 'sandbox'],
    'git': ['workspace'],
    'call_external_tool': ['network', 'staging'],
  };

  static const Map<String, String> _defaultEnvironments = {
    'web_search': 'network',
    'read_url': 'network',
    'call_external_tool': 'network',
  };

  ToolPermissionDecision evaluate({
    required String toolName,
    required Map<String, dynamic> params,
  }) {
    final defaultEnvironment = _defaultEnvironments[toolName] ?? 'workspace';
    final environment = (params['environment']?.toString().trim().isNotEmpty ==
            true)
        ? params['environment'].toString().trim()
        : defaultEnvironment;
    final approvalMode = _defaultApprovalModes[toolName] ?? 'manual';
    final allowedEnvironments =
        _allowedEnvironments[toolName] ?? const ['workspace'];

    if (!allowedEnvironments.contains(environment)) {
      return ToolPermissionDecision(
        allowed: false,
        requiresConfirmation: false,
        approvalMode: approvalMode,
        environment: environment,
        reason:
            'Tool "$toolName" is not allowed in environment "$environment". Allowed environments: ${allowedEnvironments.join(', ')}.',
      );
    }

    final destructive = _isDestructive(toolName, params);
    final confirmed = params['confirm'] == true &&
        (params['confirmation_reason']?.toString().trim().isNotEmpty == true);

    if (destructive && !confirmed) {
      return ToolPermissionDecision(
        allowed: false,
        requiresConfirmation: true,
        approvalMode: approvalMode,
        environment: environment,
        reason:
            'Destructive action detected for "$toolName". Re-issue with {"confirm": true, "confirmation_reason": "..."} only if the action is necessary.',
      );
    }

    if (toolName == 'call_external_tool' &&
        (params['credential_scope']?.toString().trim().isEmpty ?? true)) {
      return ToolPermissionDecision(
        allowed: false,
        requiresConfirmation: false,
        approvalMode: approvalMode,
        environment: environment,
        reason:
            'External tool calls must declare a credential_scope so credentials remain scoped and auditable.',
      );
    }

    return ToolPermissionDecision(
      allowed: true,
      requiresConfirmation: false,
      approvalMode: approvalMode,
      environment: environment,
      reason: destructive
          ? 'Destructive action explicitly confirmed.'
          : 'Policy check passed.',
    );
  }

  Future<Map<String, String>> resolveScopedHeaders({
    required String scope,
    required String environment,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_credentialPrefsKey) ?? const [];
    final credentials = raw
        .map((entry) {
          try {
            return ScopedCredential.fromJson(
              jsonDecode(entry) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<ScopedCredential>();

    for (final credential in credentials) {
      final scopeMatch =
          credential.scopes.isEmpty || credential.scopes.contains(scope);
      final envMatch = credential.environments.isEmpty ||
          credential.environments.contains(environment);
      if (scopeMatch && envMatch && credential.value.isNotEmpty) {
        return {credential.headerName: credential.value};
      }
    }

    return const {};
  }

  Future<void> recordAudit(ToolAuditEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadAuditLog();
    current.insert(0, entry);
    await prefs.setString(
      _auditPrefsKey,
      jsonEncode(
        current
            .take(_maxAuditEntries)
            .map((audit) => audit.toJson())
            .toList(),
      ),
    );
  }

  Future<List<ToolAuditEntry>> loadAuditLog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_auditPrefsKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => ToolAuditEntry.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }

  bool _isDestructive(String toolName, Map<String, dynamic> params) {
    switch (toolName) {
      case 'git':
        final command = params['command']?.toString().toLowerCase() ?? '';
        return command == 'reset' || command == 'restore';
      case 'run_terminal_command':
        final command = params['command']?.toString().toLowerCase() ?? '';
        final patterns = [
          'rm -rf',
          'git reset --hard',
          'mkfs',
          'dd ',
          'shutdown',
          'reboot',
          'docker system prune',
          'drop database',
        ];
        return patterns.any(command.contains);
      case 'call_external_tool':
        final action = params['action']?.toString().toLowerCase() ?? '';
        return ['delete', 'destroy', 'drop', 'purge', 'reset']
            .contains(action);
      default:
        return false;
    }
  }
}
