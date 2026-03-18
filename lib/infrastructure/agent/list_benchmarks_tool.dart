import '../services/agent_eval_service.dart';
import 'agent_tool.dart';

class ListBenchmarksTool implements AgentTool {
  @override
  String get name => 'list_benchmarks';

  @override
  String get displayName => 'List Benchmarks';

  @override
  String get uiIcon => 'checklist';

  @override
  String get description =>
      'Lists built-in benchmark tasks used to evaluate agent quality.';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    return AgentEvalService.benchmarks
        .map(
          (benchmark) =>
              '- ${benchmark.title} [${benchmark.id}]: ${benchmark.description}',
        )
        .join('\n');
  }
}
