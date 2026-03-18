import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/agent_run.dart';

final agentRunServiceProvider = Provider<AgentRunService>((ref) {
  return AgentRunService();
});

class AgentRunService {
  static const String _key = 'agent_runs';
  final Uuid _uuid = const Uuid();

  Future<List<AgentRun>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((entry) {
          try {
            return AgentRun.fromJson(jsonDecode(entry) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<AgentRun>()
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<AgentRun> createRun(String task) async {
    final now = DateTime.now();
    final taskId = _uuid.v4();
    final run = AgentRun(
      id: _uuid.v4(),
      taskId: taskId,
      task: task,
      status: 'running',
      currentPhase: 'queued',
      createdAt: now,
      updatedAt: now,
      lastHeartbeatAt: now,
      deadlineAt: now.add(const Duration(minutes: 2)),
      traces: [
        AgentRunTrace(
          timestamp: now,
          source: 'User',
          target: 'Orchestrator',
          type: 'run_created',
          summary: task,
        ),
      ],
    );
    await save(run);
    return run;
  }

  Future<void> save(AgentRun run) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();
    final index = all.indexWhere((existing) => existing.id == run.id);

    if (index >= 0) {
      all[index] = run;
    } else {
      all.insert(0, run);
    }

    await prefs.setStringList(
      _key,
      all.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }

  Future<AgentRun?> getById(String runId) async {
    final all = await loadAll();
    for (final run in all) {
      if (run.id == runId) return run;
    }
    return null;
  }

  Future<AgentRun?> getLatestActiveRun() async {
    final all = await loadAll();
    for (final run in all) {
      if (run.status == 'running') return run;
    }
    return null;
  }

  Future<void> appendTrace(
    String runId,
    AgentRunTrace trace, {
    String? status,
    String? phase,
    String? activeAgent,
    String? lastTransitionReason,
    int? retryCount,
    int? toolCallCount,
    int? toolResultCount,
    DateTime? deadlineAt,
    DateTime? heartbeatAt,
    AgentRunCheckpoint? checkpoint,
  }) async {
    final all = await loadAll();
    final index = all.indexWhere((run) => run.id == runId);
    if (index < 0) return;

    final run = all[index];
    final updated = run.copyWith(
      status: status ?? run.status,
      currentPhase: phase ?? run.currentPhase,
      activeAgent: activeAgent ?? run.activeAgent,
      lastTransitionReason:
          lastTransitionReason ?? run.lastTransitionReason,
      retryCount: retryCount ?? run.retryCount,
      updatedAt: trace.timestamp,
      deadlineAt: deadlineAt ?? run.deadlineAt,
      lastHeartbeatAt: heartbeatAt ?? trace.timestamp,
      toolCallCount: toolCallCount ?? run.toolCallCount,
      toolResultCount: toolResultCount ?? run.toolResultCount,
      traces: [...run.traces, trace],
      checkpoints: checkpoint == null
          ? run.checkpoints
          : [...run.checkpoints, checkpoint],
    );
    await save(updated);
  }
}
