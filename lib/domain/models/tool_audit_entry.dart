class ToolAuditEntry {
  final String id;
  final String toolName;
  final String approvalMode;
  final String environment;
  final bool allowed;
  final bool requiresConfirmation;
  final String reason;
  final Map<String, dynamic> params;
  final String resultSummary;
  final DateTime createdAt;

  const ToolAuditEntry({
    required this.id,
    required this.toolName,
    required this.approvalMode,
    required this.environment,
    required this.allowed,
    required this.requiresConfirmation,
    required this.reason,
    required this.params,
    required this.resultSummary,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'toolName': toolName,
        'approvalMode': approvalMode,
        'environment': environment,
        'allowed': allowed,
        'requiresConfirmation': requiresConfirmation,
        'reason': reason,
        'params': params,
        'resultSummary': resultSummary,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ToolAuditEntry.fromJson(Map<String, dynamic> json) {
    return ToolAuditEntry(
      id: json['id']?.toString() ?? '',
      toolName: json['toolName']?.toString() ?? '',
      approvalMode: json['approvalMode']?.toString() ?? 'auto',
      environment: json['environment']?.toString() ?? 'workspace',
      allowed: json['allowed'] as bool? ?? false,
      requiresConfirmation: json['requiresConfirmation'] as bool? ?? false,
      reason: json['reason']?.toString() ?? '',
      params: json['params'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['params'] as Map<String, dynamic>)
          : const {},
      resultSummary: json['resultSummary']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
