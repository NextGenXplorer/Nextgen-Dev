import 'dart:io';

import '../storage/workspace_manager.dart';
import 'agent_tool.dart';

class FileSearchTool implements AgentTool {
  final WorkspaceManager workspaceManager;

  FileSearchTool(this.workspaceManager);

  @override
  String get name => 'search_files';

  @override
  String get displayName => 'Search Files';

  @override
  String get uiIcon => 'find_in_page';

  @override
  String get description =>
      'Searches files in the local workspace for a text query and returns matching file paths with line snippets. Useful for repo-scale retrieval before editing.';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final query = params['query'] as String?;
    final projectId = params['project_id'] as String?;
    final maxResults = (params['max_results'] as num?)?.toInt() ?? 20;

    if (query == null || query.trim().isEmpty) {
      return 'Error: query is required.';
    }

    try {
      final rootPath = projectId != null && projectId.trim().isNotEmpty
          ? await workspaceManager.resolvePath(projectId)
          : await workspaceManager.getWorkspaceRootPath();

      final root = Directory(rootPath);
      if (!await root.exists()) {
        return 'Error: Search root does not exist.';
      }

      final matches = <String>[];
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (matches.length >= maxResults) break;
        if (entity is! File) continue;

        final path = entity.path;
        if (_shouldSkip(path)) continue;

        try {
          final content = await entity.readAsString();
          final lines = content.split('\n');
          for (int i = 0; i < lines.length; i++) {
            if (lines[i].toLowerCase().contains(query.toLowerCase())) {
              matches.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
              if (matches.length >= maxResults) break;
            }
          }
        } catch (_) {
          // Ignore binary/unreadable files.
        }
      }

      if (matches.isEmpty) {
        return 'No matches found for "$query".';
      }
      return matches.join('\n');
    } catch (e) {
      return 'Error while searching files: $e';
    }
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
