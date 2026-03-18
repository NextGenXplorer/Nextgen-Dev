import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/agent_eval.dart';
import '../../domain/models/agent_run.dart';

final agentEvalServiceProvider = Provider<AgentEvalService>((ref) {
  return AgentEvalService();
});

class AgentEvalService {
  static const String _resultsKey = 'agent_eval_results';
  final Uuid _uuid = const Uuid();

  static const benchmarks = <AgentBenchmarkTask>[
    AgentBenchmarkTask(
      id: 'scaffold_app',
      title: 'Scaffold App',
      description: 'Create a fresh app skeleton with coherent structure.',
      prompt: 'Scaffold a new production-ready starter application.',
    ),
    AgentBenchmarkTask(
      id: 'fix_bug',
      title: 'Fix Bug',
      description: 'Diagnose and repair a failing implementation.',
      prompt: 'Fix a failing feature and verify the repair with a test/build.',
    ),
    AgentBenchmarkTask(
      id: 'refactor_module',
      title: 'Refactor Module',
      description: 'Improve architecture without breaking behavior.',
      prompt: 'Refactor an existing module for clarity and maintainability.',
    ),
    AgentBenchmarkTask(
      id: 'run_preview',
      title: 'Run Preview',
      description: 'Prepare and start a local preview environment.',
      prompt: 'Prepare dependencies and start a working project preview.',
    ),
    AgentBenchmarkTask(
      id: 'recover_build',
      title: 'Recover Build',
      description: 'Recover from a failing build and return to green.',
      prompt: 'Analyze a broken build, fix it, and prove the build passes.',
    ),
  ];

  Future<List<AgentEvalResult>> loadAllResults() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_resultsKey) ?? [];
    return raw
        .map((entry) {
          try {
            return AgentEvalResult.fromJson(
              jsonDecode(entry) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<AgentEvalResult>()
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveResult(AgentEvalResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAllResults();
    final index = all.indexWhere((entry) => entry.id == result.id);

    if (index >= 0) {
      all[index] = result;
    } else {
      all.insert(0, result);
    }

    await prefs.setStringList(
      _resultsKey,
      all.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }

  Future<AgentEvalResult> gradeRun(
    AgentRun run, {
    String? projectPath,
  }) async {
    final criteria = <EvalCriterionResult>[
      _gradeCompletion(run),
      _gradeBuild(run),
      _gradeTests(run),
      await _gradePlaceholders(projectPath),
      _gradeUx(run),
    ];

    final passed = criteria.where((c) => c.status == EvalGradeStatus.passed).length;
    final score = criteria.isEmpty ? 0.0 : passed / criteria.length;

    final result = AgentEvalResult(
      id: _uuid.v4(),
      runId: run.id,
      createdAt: DateTime.now(),
      score: score,
      criteria: criteria,
    );
    await saveResult(result);
    return result;
  }

  EvalCriterionResult _gradeCompletion(AgentRun run) {
    final passed = run.status == 'completed';
    return EvalCriterionResult(
      name: 'completed_task',
      status: passed ? EvalGradeStatus.passed : EvalGradeStatus.failed,
      details: passed
          ? 'Run reached a completed terminal state.'
          : 'Run did not complete successfully.',
    );
  }

  EvalCriterionResult _gradeBuild(AgentRun run) {
    final buildSignal = run.traces.any((trace) {
      final summary = trace.summary.toLowerCase();
      return summary.contains('build') &&
          (summary.contains('passed') ||
              summary.contains('success') ||
              summary.contains('exit code: 0'));
    });

    return EvalCriterionResult(
      name: 'build_green',
      status: buildSignal
          ? EvalGradeStatus.passed
          : EvalGradeStatus.inconclusive,
      details: buildSignal
          ? 'Run traces indicate a successful build signal.'
          : 'No definitive successful build signal was found in traces.',
    );
  }

  EvalCriterionResult _gradeTests(AgentRun run) {
    final testSignal = run.traces.any((trace) {
      final summary = trace.summary.toLowerCase();
      return summary.contains('passed') ||
          summary.contains('testing passed') ||
          summary.contains('tests passed');
    });

    return EvalCriterionResult(
      name: 'tests_green',
      status: testSignal
          ? EvalGradeStatus.passed
          : EvalGradeStatus.inconclusive,
      details: testSignal
          ? 'Run traces indicate successful test verification.'
          : 'No definitive successful test signal was found in traces.',
    );
  }

  Future<EvalCriterionResult> _gradePlaceholders(String? projectPath) async {
    if (projectPath == null || projectPath.trim().isEmpty) {
      return const EvalCriterionResult(
        name: 'no_placeholders',
        status: EvalGradeStatus.inconclusive,
        details: 'Project path unavailable, placeholder scan skipped.',
      );
    }

    final root = Directory(projectPath);
    if (!await root.exists()) {
      return const EvalCriterionResult(
        name: 'no_placeholders',
        status: EvalGradeStatus.inconclusive,
        details: 'Project path does not exist, placeholder scan skipped.',
      );
    }

    final hits = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (_shouldSkip(entity.path)) continue;

      try {
        final contents = await entity.readAsString();
        final lower = contents.toLowerCase();
        if (lower.contains('todo') ||
            lower.contains('placeholder') ||
            lower.contains('tbd')) {
          hits.add(entity.path);
          if (hits.length >= 10) break;
        }
      } catch (_) {
        // Ignore unreadable files.
      }
    }

    if (hits.isEmpty) {
      return const EvalCriterionResult(
        name: 'no_placeholders',
        status: EvalGradeStatus.passed,
        details: 'No TODO/placeholder/TBD markers were found.',
      );
    }

    return EvalCriterionResult(
      name: 'no_placeholders',
      status: EvalGradeStatus.failed,
      details: 'Found placeholder markers in: ${hits.join(', ')}',
    );
  }

  EvalCriterionResult _gradeUx(AgentRun run) {
    final previewReached = run.traces.any(
      (trace) => trace.target == 'PreviewAgent' || trace.source == 'PreviewAgent',
    );

    return EvalCriterionResult(
      name: 'ux_quality',
      status: EvalGradeStatus.inconclusive,
      details: previewReached
          ? 'Preview phase was reached, but visual UX grading is not yet automated.'
          : 'UX quality requires visual grading and is currently inconclusive.',
    );
  }

  bool _shouldSkip(String path) {
    const ignored = [
      '/.git/',
      '/node_modules/',
      '/build/',
      '/dist/',
      '/.dart_tool/',
      '/coverage/',
    ];
    return ignored.any(path.contains);
  }
}
