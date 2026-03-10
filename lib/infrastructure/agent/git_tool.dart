import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/git_service.dart';
import 'agent_tool.dart';

class GitTool implements AgentTool {
  @override
  String get name => 'git';

  @override
  String get displayName => 'Git Control';

  @override
  String get uiIcon => 'device_hub'; // Closest generic material icon for branching/graphs

  @override
  String get description =>
      'Interact with Git for safety. Commands: "status" (see changes), "log" (recent commits), "restore" (revert a file to its last committed state), "reset" (hard reset the entire project). Required param: command, optional: filePath, commitHash.';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final command = params['command'] as String?;
    final projectName = params['project_name'] as String?;
    final filePath = params['file_path'] as String?;
    final commitHash = params['commit_hash'] as String?;

    if (command == null || command.isEmpty) {
      return 'Error: No git command provided.';
    }

    if (projectName == null || projectName.isEmpty) {
      return 'Error: Must provide project_name parameter to locate the workspace.';
    }

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final projectDir = '${docDir.path}/Projects/$projectName';
      
      if (!await Directory(projectDir).exists()) {
        return 'Error: Project folder not found.';
      }

      final gitService = GitService(workingDirectory: projectDir);

      switch (command) {
        case 'status':
          return await gitService.status();
        case 'log':
          return await gitService.log();
        case 'restore':
          if (filePath == null) return 'Error: file_path required for restore.';
          return await gitService.restore(filePath);
        case 'reset':
          return await gitService.resetHard(commit: commitHash ?? 'HEAD');
        default:
          return 'Error: Unsupported git command. Use "status", "log", "restore", or "reset".';
      }
    } catch (e) {
      return 'Git operation failed: $e';
    }
  }
}
