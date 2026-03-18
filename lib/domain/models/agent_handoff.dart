class AgentHandoff {
  final String status;
  final String reason;
  final List<String> artifacts;
  final List<String> changedFiles;
  final List<String> commandsRun;
  final List<String> evidence;
  final String? nextRecommendedAgent;
  final Map<String, dynamic> data;

  const AgentHandoff({
    required this.status,
    required this.reason,
    this.artifacts = const [],
    this.changedFiles = const [],
    this.commandsRun = const [],
    this.evidence = const [],
    this.nextRecommendedAgent,
    this.data = const {},
  });

  Map<String, dynamic> toJson() => {
        'status': status,
        'reason': reason,
        'artifacts': artifacts,
        'changed_files': changedFiles,
        'commands_run': commandsRun,
        'evidence': evidence,
        'next_recommended_agent': nextRecommendedAgent,
        'data': data,
      };

  factory AgentHandoff.fromJson(Map<String, dynamic> json) {
    return AgentHandoff(
      status: json['status']?.toString() ?? 'unknown',
      reason: json['reason']?.toString() ?? '',
      artifacts: _toStringList(json['artifacts']),
      changedFiles: _toStringList(json['changed_files']),
      commandsRun: _toStringList(json['commands_run']),
      evidence: _toStringList(json['evidence']),
      nextRecommendedAgent: json['next_recommended_agent']?.toString(),
      data: json['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['data'] as Map<String, dynamic>)
          : const {},
    );
  }

  static AgentHandoff? maybeFrom(dynamic payload) {
    if (payload is Map<String, dynamic> &&
        payload.containsKey('status') &&
        payload.containsKey('reason') &&
        payload.containsKey('artifacts') &&
        payload.containsKey('changed_files') &&
        payload.containsKey('commands_run') &&
        payload.containsKey('evidence')) {
      return AgentHandoff.fromJson(payload);
    }
    return null;
  }

  static dynamic unwrapData(dynamic payload) {
    final handoff = maybeFrom(payload);
    if (handoff != null) {
      return handoff.data;
    }
    return payload;
  }

  static String summarize(dynamic payload) {
    final handoff = maybeFrom(payload);
    if (handoff == null) {
      return payload?.toString() ?? '';
    }

    final nextAgent = handoff.nextRecommendedAgent;
    if (nextAgent != null && nextAgent.isNotEmpty) {
      return '${handoff.status}: ${handoff.reason} → $nextAgent';
    }
    return '${handoff.status}: ${handoff.reason}';
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }
}
