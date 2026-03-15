import 'dart:io';
import '../storage/workspace_manager.dart';
import '../services/git_service.dart';
import 'agent_tool.dart';

/// Surgically replaces text inside an existing file, or fully overwrites it.
class EditFileTool implements AgentTool {
  final WorkspaceManager _workspaceManager;
  EditFileTool(this._workspaceManager);

  @override
  String get name => 'edit_file';

  @override
  String get displayName => 'Edit File';

  @override
  String get uiIcon => 'edit_document';

  @override
  String get description =>
      'Replaces specific text inside an existing file. '
      'Set target_text to "" or "OVERWRITE" to replace the entire file.';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final path = params['path'] as String?;
    final targetText = params['target_text'] as String?;
    final replacementText = params['replacement_text'] as String?;

    if (path == null || path.trim().isEmpty) {
      return 'Error: No file path provided.';
    }
    if (replacementText == null) {
      return 'Error: No replacement_text provided.';
    }

    try {
      final absolutePath = await _workspaceManager.resolvePath(path);
      File file = File(absolutePath);

      if (!await file.exists()) {
        return 'Error: File not found at $path. Current root: ${file.path}';
      }

      String content = await file.readAsString();

      // ── Git backup helper ─────────────────────────────────────────────────
      Future<void> gitBackup() async {
        final gitService = GitService(workingDirectory: file.parent.path);
        try {
          await gitService.init();
          await gitService.addAll();
          await gitService.commit(
            'Auto-backup before editing ${file.uri.pathSegments.last}',
          );
        } catch (_) {}
      }

      // ── Full-file overwrite mode ──────────────────────────────────────────
      final isFullOverwrite =
          targetText == null ||
          targetText.trim().isEmpty ||
          targetText == 'OVERWRITE';

      if (isFullOverwrite) {
        await gitBackup();
        await file.writeAsString(replacementText);
        final lines = replacementText.split('\n').length;
        return 'SUCCESS: Overwrote entire file $path ($lines lines).';
      }

      // ── Surgical replacement mode ─────────────────────────────────────────
      if (!content.contains(targetText)) {
        final snippet = content.length > 400 ? content.substring(0, 400) : content;
        return 'Error: Target text not found in $path.\n'
            'File starts with:\n```\n$snippet\n```';
      }

      await gitBackup();
      content = content.replaceFirst(targetText, replacementText);
      await file.writeAsString(content);

      return 'SUCCESS: Edited $path. Target text replaced.';
    } catch (e) {
      return 'Failed to edit file: $e';
    }
  }
}
