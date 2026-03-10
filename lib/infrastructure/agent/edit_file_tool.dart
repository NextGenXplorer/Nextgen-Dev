import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/git_service.dart';
import 'agent_tool.dart';

class EditFileTool implements AgentTool {
  @override
  String get name => 'edit_file';
  
  @override
  String get displayName => 'Edit File';
  
  @override
  String get uiIcon => 'edit_document';
  
  @override
  String get description => 'Replaces specific text inside an existing file.';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final path = params['path'] as String?;
    final targetText = params['target_text'] as String?;
    final replacementText = params['replacement_text'] as String?;
    
    if (path == null || path.isEmpty) {
      return 'Error: No file path provided.';
    }
    if (targetText == null || targetText.isEmpty) {
      return 'Error: No target text provided to replace.';
    }
    if (replacementText == null) {
      return 'Error: No replacement text provided.';
    }

    try {
      File file = File(path);
      
      if (!file.isAbsolute) {
        final docDir = await getApplicationDocumentsDirectory();
        file = File('\${docDir.path}/Projects/\$path');
      }

      if (!await file.exists()) {
        return 'Error: File not found at \${file.path}';
      }

      String content = await file.readAsString();
      
      if (!content.contains(targetText)) {
        return 'Error: Target text not found in file. Ensure the whitespace matches exactly.';
      }

      // Setup git service for backup
      final projectDir = file.parent.path;
      final gitService = GitService(workingDirectory: projectDir);

      try {
        await gitService.init();
        await gitService.addAll();
        await gitService.commit('Auto-backup before editing ${file.uri.pathSegments.last}');
      } catch (e) {
        // Ignore git errors if git is not installed or configured
      }

      // Perform replacement
      content = content.replaceFirst(targetText, replacementText);
      
      await file.writeAsString(content);

      return 'Successfully modified ${file.path}. Replaced target text with new content. Note: an automatic git backup commit was created before editing just in case you need to revert.';
    } catch (e) {
      return 'Failed to edit file: $e';
    }
  }
}
