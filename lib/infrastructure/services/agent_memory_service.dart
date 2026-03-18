import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/agent_memory.dart';

final agentMemoryServiceProvider = Provider<AgentMemoryService>((ref) {
  return AgentMemoryService();
});

class AgentMemoryService {
  static const _prefsKey = 'nextgen_agent_memories_v1';
  static const _maxEntries = 250;

  Future<void> remember({
    required String category,
    required String content,
    String? projectPath,
    String? agentName,
    String? fingerprint,
    Map<String, dynamic> metadata = const {},
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final memories = await _load();
    final dedupeKey = fingerprint ?? '$category::$projectPath::$trimmed';
    memories.removeWhere(
      (memory) =>
          (memory.fingerprint?.isNotEmpty == true &&
              memory.fingerprint == dedupeKey) ||
          (memory.category == category &&
              memory.projectPath == projectPath &&
              memory.content == trimmed),
    );

    memories.insert(
      0,
      AgentMemory(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        category: category,
        content: trimmed,
        projectPath: projectPath,
        agentName: agentName,
        fingerprint: dedupeKey,
        createdAt: DateTime.now(),
        metadata: metadata,
      ),
    );

    await _save(memories.take(_maxEntries).toList());
  }

  Future<void> rememberProjectMemory(
    String content, {
    String? projectPath,
    String? agentName,
    String? fingerprint,
    Map<String, dynamic> metadata = const {},
  }) {
    return remember(
      category: 'project_memory',
      content: content,
      projectPath: projectPath,
      agentName: agentName,
      fingerprint: fingerprint,
      metadata: metadata,
    );
  }

  Future<void> rememberRepoMemory(
    String content, {
    String? agentName,
    String? fingerprint,
    Map<String, dynamic> metadata = const {},
  }) {
    return remember(
      category: 'repo_memory',
      content: content,
      agentName: agentName,
      fingerprint: fingerprint,
      metadata: metadata,
    );
  }

  Future<void> rememberUserPreference(
    String content, {
    String? projectPath,
    String? fingerprint,
  }) {
    return remember(
      category: 'user_preference',
      content: content,
      projectPath: projectPath,
      fingerprint: fingerprint,
    );
  }

  Future<void> rememberFailurePattern(
    String content, {
    String? projectPath,
    String? agentName,
    String? fingerprint,
  }) {
    return remember(
      category: 'failure_pattern',
      content: content,
      projectPath: projectPath,
      agentName: agentName,
      fingerprint: fingerprint,
    );
  }

  Future<void> rememberSuccessfulWorkflow(
    String content, {
    String? projectPath,
    String? fingerprint,
    Map<String, dynamic> metadata = const {},
  }) {
    return remember(
      category: 'successful_workflow',
      content: content,
      projectPath: projectPath,
      fingerprint: fingerprint,
      metadata: metadata,
    );
  }

  Future<void> captureUserPreferencesFromTask(
    String task, {
    String? projectPath,
  }) async {
    final matches = RegExp(
      r'(?i)\b(prefer|please|must|should|always|never|avoid|use|don\'t|do not)\b[^\n\.!]*',
    ).allMatches(task);

    for (final match in matches.take(6)) {
      await rememberUserPreference(
        match.group(0)!,
        projectPath: projectPath,
        fingerprint: 'user_pref:${match.group(0)!.toLowerCase()}',
      );
    }
  }

  Future<List<AgentMemory>> search(
    String query, {
    String? projectPath,
    List<String>? categories,
    int limit = 3,
  }) async {
    final tokens = _tokenize(query);
    final memories = await _load();
    final filtered = memories.where((memory) {
      final categoryMatch =
          categories == null || categories.contains(memory.category);
      final projectMatch =
          memory.projectPath == null ||
          projectPath == null ||
          memory.projectPath == projectPath;
      return categoryMatch && projectMatch;
    }).toList();

    filtered.sort((a, b) {
      final aScore = _score(a, tokens, projectPath);
      final bScore = _score(b, tokens, projectPath);
      return bScore.compareTo(aScore);
    });

    return filtered.take(limit).toList();
  }

  Future<String> buildExecutionContext({
    required String task,
    String? projectPath,
    String? agentName,
  }) async {
    final sections = <String>[];

    Future<void> addSection(String title, List<String> categories) async {
      final items = await search(
        task,
        projectPath: projectPath,
        categories: categories,
        limit: 3,
      );
      if (items.isEmpty) return;
      sections.add('### $title');
      for (final item in items) {
        final source =
            item.agentName != null ? ' (${item.agentName})' : '';
        sections.add('- ${item.content}$source');
      }
    }

    await addSection('Project memory', ['project_memory']);
    await addSection('Repo memory', ['repo_memory']);
    await addSection('User preferences', ['user_preference']);
    await addSection('Failure patterns to avoid', ['failure_pattern']);
    await addSection(
      'Prior successful workflows',
      ['successful_workflow'],
    );

    if (sections.isEmpty) return '';

    return '''
MEMORY CONTEXT${agentName != null ? ' for $agentName' : ''}:
${sections.join('\n')}

Use this memory to respect known preferences, avoid repeated mistakes, and reuse proven workflows when relevant.
''';
  }

  Future<List<AgentMemory>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => AgentMemory.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }

  Future<void> _save(List<AgentMemory> memories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(memories.map((memory) => memory.toJson()).toList()),
    );
  }

  int _score(AgentMemory memory, Set<String> tokens, String? projectPath) {
    final contentTokens = _tokenize(memory.content);
    final overlap = tokens.intersection(contentTokens).length;
    final projectBonus =
        projectPath != null && memory.projectPath == projectPath ? 5 : 0;
    final recencyBonus = memory.createdAt.millisecondsSinceEpoch ~/ 1000000000;
    return overlap * 100 + projectBonus + recencyBonus;
  }

  Set<String> _tokenize(String input) {
    return input
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.trim().length >= 3)
        .toSet();
  }
}
