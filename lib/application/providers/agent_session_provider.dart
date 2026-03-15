import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ui/widgets/agent_task_progress_bubble.dart';
import '../../domain/models/chat_message.dart' as app_models;

// ── Agent Session State ──────────────────────────────────────────────────────
// Persists ALL agent work across screen navigation. No state is lost when
// the user switches between Projects, Terminal, Deploy, etc.

class AgentSessionState {
  final bool isRunning;
  final List<AgentTask> tasks;
  final String? currentPlan;
  final String? activeProjectId;
  final String? activeProjectPath;
  final List<String> changedFiles;
  final List<app_models.ChatMessage> chatHistory;
  final Map<String, dynamic>? lastPlanPayload;

  const AgentSessionState({
    this.isRunning = false,
    this.tasks = const [],
    this.currentPlan,
    this.activeProjectId,
    this.activeProjectPath,
    this.changedFiles = const [],
    this.chatHistory = const [],
    this.lastPlanPayload,
  });

  AgentSessionState copyWith({
    bool? isRunning,
    List<AgentTask>? tasks,
    String? currentPlan,
    String? activeProjectId,
    String? activeProjectPath,
    List<String>? changedFiles,
    List<app_models.ChatMessage>? chatHistory,
    Map<String, dynamic>? lastPlanPayload,
  }) {
    return AgentSessionState(
      isRunning: isRunning ?? this.isRunning,
      tasks: tasks ?? this.tasks,
      currentPlan: currentPlan ?? this.currentPlan,
      activeProjectId: activeProjectId ?? this.activeProjectId,
      activeProjectPath: activeProjectPath ?? this.activeProjectPath,
      changedFiles: changedFiles ?? this.changedFiles,
      chatHistory: chatHistory ?? this.chatHistory,
      lastPlanPayload: lastPlanPayload ?? this.lastPlanPayload,
    );
  }

  /// True if all tasks are completed and agent is not running.
  bool get isComplete =>
      !isRunning &&
      tasks.isNotEmpty &&
      tasks.every((t) => t.status == TaskStatus.completed);
}

class AgentSessionNotifier extends StateNotifier<AgentSessionState> {
  AgentSessionNotifier() : super(const AgentSessionState());

  void setRunning(bool running) => state = state.copyWith(isRunning: running);

  void setActiveProject(String id, String path) =>
      state = state.copyWith(activeProjectId: id, activeProjectPath: path);

  void setPlan(String plan, Map<String, dynamic> payload) =>
      state = state.copyWith(currentPlan: plan, lastPlanPayload: payload);

  void upsertTask(AgentTask task) {
    final existing = state.tasks.indexWhere((t) => t.title == task.title);
    final updated = List<AgentTask>.from(state.tasks);
    if (existing != -1) {
      updated[existing] = task;
    } else {
      updated.add(task);
    }
    state = state.copyWith(tasks: updated);
  }

  void addChangedFile(String path) {
    if (state.changedFiles.contains(path)) return;
    state = state.copyWith(changedFiles: [...state.changedFiles, path]);
  }

  void addMessage(app_models.ChatMessage msg) =>
      state = state.copyWith(chatHistory: [...state.chatHistory, msg]);

  void updateLastMessage(app_models.ChatMessage msg) {
    if (state.chatHistory.isEmpty) {
      addMessage(msg);
      return;
    }
    final updated = List<app_models.ChatMessage>.from(state.chatHistory);
    updated[updated.length - 1] = msg;
    state = state.copyWith(chatHistory: updated);
  }

  void reset() => state = const AgentSessionState();
}

/// Global provider — persisted for the lifetime of the app (not per-widget).
/// Using [keepAlive] so it survives screen pushes/pops.
final agentSessionProvider =
    StateNotifierProvider<AgentSessionNotifier, AgentSessionState>(
  (ref) => AgentSessionNotifier(),
);
