import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/git_service.dart';
import 'agent_tool.dart';

class GitTool implements AgentTool {
  final String? activeProjectPath;
  final String? Function()? projectPathProvider;

  GitTool({this.activeProjectPath, this.projectPathProvider});

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
    final confirmed = params['confirm'] == true;

    if (command == null || command.isEmpty) {
      return 'Error: No git command provided.';
    }

    try {
      String projectDir = '';
      if ((params['project_path']?.toString().trim().isNotEmpty ?? false)) {
        projectDir = params['project_path'].toString().trim();
      } else if ((projectPathProvider?.call()?.isNotEmpty ?? false)) {
        projectDir = projectPathProvider!.call()!;
      } else if (activeProjectPath != null && activeProjectPath!.isNotEmpty) {
        projectDir = activeProjectPath!;
      } else if (projectName != null && projectName.isNotEmpty) {
        final docDir = await getApplicationDocumentsDirectory();
        projectDir = '${docDir.path}/Projects/$projectName';
      } else {
        return 'Error: Must provide project_path/project_name or have an active project.';
      }

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
          if (!confirmed) {
            return 'Error: restore requires confirm=true and confirmation_reason.';
          }
          return await gitService.restore(filePath);
        case 'reset':
          if (!confirmed) {
            return 'Error: reset requires confirm=true and confirmation_reason.';
          }
          return await gitService.resetHard(commit: commitHash ?? 'HEAD');
        default:
          return 'Error: Unsupported git command. Use "status", "log", "restore", or "reset".';
      }
    } catch (e) {
      return 'Git operation failed: $e';
    }
  }
}
