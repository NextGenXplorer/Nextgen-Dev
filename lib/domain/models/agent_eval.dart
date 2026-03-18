import 'dart:convert';

enum EvalGradeStatus { passed, failed, inconclusive }

class EvalCriterionResult {
  final String name;
  final EvalGradeStatus status;
  final String details;

  const EvalCriterionResult({
    required this.name,
    required this.status,
    required this.details,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status.name,
    'details': details,
  };

  factory EvalCriterionResult.fromJson(Map<String, dynamic> json) =>
      EvalCriterionResult(
        name: json['name'] as String? ?? '',
        status: EvalGradeStatus.values.firstWhere(
          (status) => status.name == json['status'],
          orElse: () => EvalGradeStatus.inconclusive,
        ),
        details: json['details'] as String? ?? '',
      );
}

class AgentBenchmarkTask {
  final String id;
  final String title;
  final String description;
  final String prompt;

  const AgentBenchmarkTask({
    required this.id,
    required this.title,
    required this.description,
    required this.prompt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'prompt': prompt,
  };

  factory AgentBenchmarkTask.fromJson(Map<String, dynamic> json) =>
      AgentBenchmarkTask(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
      );
}

class AgentEvalResult {
  final String id;
  final String runId;
  final DateTime createdAt;
  final double score;
  final List<EvalCriterionResult> criteria;

  const AgentEvalResult({
    required this.id,
    required this.runId,
    required this.createdAt,
    required this.score,
    required this.criteria,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'runId': runId,
    'createdAt': createdAt.toIso8601String(),
    'score': score,
    'criteria': criteria.map((criterion) => criterion.toJson()).toList(),
  };

  factory AgentEvalResult.fromJson(Map<String, dynamic> json) => AgentEvalResult(
    id: json['id'] as String? ?? '',
    runId: json['runId'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    score: (json['score'] as num?)?.toDouble() ?? 0,
    criteria: ((json['criteria'] as List?) ?? [])
        .whereType<Map>()
        .map(
          (criterion) =>
              EvalCriterionResult.fromJson(Map<String, dynamic>.from(criterion)),
        )
        .toList(),
  );

  @override
  String toString() => jsonEncode(toJson());
}
