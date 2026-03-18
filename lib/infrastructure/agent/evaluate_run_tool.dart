import '../services/agent_eval_service.dart';
import '../services/agent_run_service.dart';
import 'agent_tool.dart';

class EvaluateRunTool implements AgentTool {
  final AgentRunService runService;
  final AgentEvalService evalService;

  EvaluateRunTool({
    required this.runService,
    required this.evalService,
  });

  @override
  String get name => 'evaluate_run';

  @override
  String get displayName => 'Evaluate Run';

  @override
  String get uiIcon => 'grading';

  @override
  String get description =>
      'Grades a recorded agent run using built-in benchmark criteria and stores the eval result.';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final runId = params['run_id'] as String?;
    final projectPath = params['project_path'] as String?;

    if (runId == null || runId.trim().isEmpty) {
      return 'Error: run_id is required.';
    }

    final run = await runService.getById(runId);
    if (run == null) {
      return 'Error: Run "$runId" not found.';
    }

    final result = await evalService.gradeRun(
      run,
      projectPath: projectPath,
    );

    final criteriaSummary = result.criteria
        .map(
          (criterion) =>
              '- ${criterion.name}: ${criterion.status.name} — ${criterion.details}',
        )
        .join('\n');

    return 'Eval score: ${(result.score * 100).toStringAsFixed(0)}%\n$criteriaSummary';
  }
}
