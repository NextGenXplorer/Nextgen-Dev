import 'dart:io';
import '../storage/workspace_manager.dart';
import 'agent_tool.dart';

class ReadFileTool implements AgentTool {
  final WorkspaceManager _workspaceManager;
  ReadFileTool(this._workspaceManager);

  @override
  String get name => 'read_file';

  @override
  String get displayName => 'Read File';

  @override
  String get uiIcon => 'description';

  @override
  String get description =>
      'Reads the contents of a specific file on the file system.';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final path = params['path'] as String?;

    if (path == null || path.isEmpty) {
      return 'Error: No file path provided.';
    }

    try {
      final absolutePath = await _workspaceManager.resolvePath(path);
      File file = File(absolutePath);

      if (!await file.exists()) {
        return 'Error: File not found at $path. Resolved to: ${file.path}';
      }

      final content = await file.readAsString();
      return 'File Content:\n```\n$content\n```';
    } catch (e) {
      return 'Failed to read file: $e';
    }
  }
}
