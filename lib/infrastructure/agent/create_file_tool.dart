import 'dart:io';
import '../storage/workspace_manager.dart';
import 'agent_tool.dart';

/// Creates a new file (or overwrites an existing one) with the given content.
class CreateFileTool implements AgentTool {
  final WorkspaceManager _workspaceManager;
  CreateFileTool(this._workspaceManager);

  @override
  String get name => 'create_file';

  @override
  String get displayName => 'Create File';

  @override
  String get uiIcon => 'note_add';

  @override
  String get description =>
      'Creates a new file at the given path with the provided content. '
      'Parent directories are created automatically.';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final path = params['path'] as String?;
    final content = params['content'] as String? ?? '';

    if (path == null || path.trim().isEmpty) {
      return 'Error: No file path provided.';
    }

    try {
      final absolutePath = await _workspaceManager.resolvePath(path);
      File file = File(absolutePath);

      // Create all intermediate directories
      await file.parent.create(recursive: true);

      // Write file content
      await file.writeAsString(content);

      final lines = content.split('\n').length;
      return 'SUCCESS: Created file $path ($lines lines). Location: ${file.path}';
    } catch (e) {
      return 'Error creating file: $e';
    }
  }
}
