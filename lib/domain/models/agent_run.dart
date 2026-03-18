import 'dart:convert';

class AgentRunTrace {
  final DateTime timestamp;
  final String source;
  final String target;
  final String type;
  final String summary;

  const AgentRunTrace({
    required this.timestamp,
    required this.source,
    required this.target,
    required this.type,
    required this.summary,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'source': source,
    'target': target,
    'type': type,
    'summary': summary,
  };

  factory AgentRunTrace.fromJson(Map<String, dynamic> json) => AgentRunTrace(
    timestamp: DateTime.parse(json['timestamp'] as String),
    source: json['source'] as String? ?? '',
    target: json['target'] as String? ?? '',
    type: json['type'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
  );
}

class AgentRunCheckpoint {
  final DateTime timestamp;
  final String phase;
  final String activeAgent;
  final String reason;
  final String payloadSummary;

  const AgentRunCheckpoint({
    required this.timestamp,
    required this.phase,
    required this.activeAgent,
    required this.reason,
    required this.payloadSummary,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'phase': phase,
    'activeAgent': activeAgent,
    'reason': reason,
    'payloadSummary': payloadSummary,
  };

  factory AgentRunCheckpoint.fromJson(Map<String, dynamic> json) =>
      AgentRunCheckpoint(
        timestamp: DateTime.parse(json['timestamp'] as String),
        phase: json['phase'] as String? ?? 'running',
        activeAgent: json['activeAgent'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        payloadSummary: json['payloadSummary'] as String? ?? '',
      );
}

class AgentRun {
  final String id;
  final String taskId;
  final String task;
  final String status;
  final String currentPhase;
  final String? activeAgent;
  final String? lastTransitionReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deadlineAt;
  final DateTime? lastHeartbeatAt;
  final int retryCount;
  final int toolCallCount;
  final int toolResultCount;
  final List<AgentRunTrace> traces;
  final List<AgentRunCheckpoint> checkpoints;

  const AgentRun({
    required this.id,
    required this.taskId,
    required this.task,
    required this.status,
    required this.currentPhase,
    this.activeAgent,
    this.lastTransitionReason,
    required this.createdAt,
    required this.updatedAt,
    this.deadlineAt,
    this.lastHeartbeatAt,
    this.retryCount = 0,
    this.toolCallCount = 0,
    this.toolResultCount = 0,
    this.traces = const [],
    this.checkpoints = const [],
  });

  AgentRun copyWith({
    String? id,
    String? taskId,
    String? task,
    String? status,
    String? currentPhase,
    Object? activeAgent = _sentinel,
    Object? lastTransitionReason = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deadlineAt = _sentinel,
    Object? lastHeartbeatAt = _sentinel,
    int? retryCount,
    int? toolCallCount,
    int? toolResultCount,
    List<AgentRunTrace>? traces,
    List<AgentRunCheckpoint>? checkpoints,
  }) {
    return AgentRun(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      task: task ?? this.task,
      status: status ?? this.status,
      currentPhase: currentPhase ?? this.currentPhase,
      activeAgent: identical(activeAgent, _sentinel)
          ? this.activeAgent
          : activeAgent as String?,
      lastTransitionReason: identical(lastTransitionReason, _sentinel)
          ? this.lastTransitionReason
          : lastTransitionReason as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deadlineAt: identical(deadlineAt, _sentinel)
          ? this.deadlineAt
          : deadlineAt as DateTime?,
      lastHeartbeatAt: identical(lastHeartbeatAt, _sentinel)
          ? this.lastHeartbeatAt
          : lastHeartbeatAt as DateTime?,
      retryCount: retryCount ?? this.retryCount,
      toolCallCount: toolCallCount ?? this.toolCallCount,
      toolResultCount: toolResultCount ?? this.toolResultCount,
      traces: traces ?? this.traces,
      checkpoints: checkpoints ?? this.checkpoints,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'task': task,
    'status': status,
    'currentPhase': currentPhase,
    'activeAgent': activeAgent,
    'lastTransitionReason': lastTransitionReason,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deadlineAt': deadlineAt?.toIso8601String(),
    'lastHeartbeatAt': lastHeartbeatAt?.toIso8601String(),
    'retryCount': retryCount,
    'toolCallCount': toolCallCount,
    'toolResultCount': toolResultCount,
    'traces': traces.map((trace) => trace.toJson()).toList(),
    'checkpoints': checkpoints.map((checkpoint) => checkpoint.toJson()).toList(),
  };

  factory AgentRun.fromJson(Map<String, dynamic> json) => AgentRun(
    id: json['id'] as String? ?? '',
    taskId: json['taskId'] as String? ?? json['id'] as String? ?? '',
    task: json['task'] as String? ?? '',
    status: json['status'] as String? ?? 'running',
    currentPhase: json['currentPhase'] as String? ?? 'queued',
    activeAgent: json['activeAgent'] as String?,
    lastTransitionReason: json['lastTransitionReason'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    deadlineAt: json['deadlineAt'] != null
        ? DateTime.parse(json['deadlineAt'] as String)
        : null,
    lastHeartbeatAt: json['lastHeartbeatAt'] != null
        ? DateTime.parse(json['lastHeartbeatAt'] as String)
        : null,
    retryCount: json['retryCount'] as int? ?? 0,
    toolCallCount: json['toolCallCount'] as int? ?? 0,
    toolResultCount: json['toolResultCount'] as int? ?? 0,
    traces: ((json['traces'] as List?) ?? [])
        .whereType<Map>()
        .map(
          (trace) =>
              AgentRunTrace.fromJson(Map<String, dynamic>.from(trace)),
        )
        .toList(),
    checkpoints: ((json['checkpoints'] as List?) ?? [])
        .whereType<Map>()
        .map(
          (checkpoint) => AgentRunCheckpoint.fromJson(
            Map<String, dynamic>.from(checkpoint),
          ),
        )
        .toList(),
  );

  @override
  String toString() => jsonEncode(toJson());
}

const Object _sentinel = Object();
