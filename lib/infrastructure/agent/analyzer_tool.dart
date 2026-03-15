import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/dart_analyzer_service.dart';
import 'agent_tool.dart';

class AnalyzerTool implements AgentTool {
  @override
  String get name => 'dart_analyzer';

  @override
  String get displayName => 'Dart Analyzer';

  @override
  String get uiIcon => 'psychology';

  @override
  String get description =>
      'Interact with the Dart Analyzer. Commands: "get_errors" (scan whole project for fatal syntax/lint errors), "format" (auto-format file), "fix" (auto-apply dart fixes). Required param: command, optional: file_path, project_name.';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final command = params['command'] as String?;
    final projectName = params['project_name'] as String?;
    final filePath = params['file_path'] as String?;

    if (command == null || command.isEmpty) {
      return 'Error: No analyzer command provided.';
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

      final analyzerService = DartAnalyzerService(workingDirectory: projectDir);

      switch (command) {
        case 'get_errors':
          return await analyzerService.getErrors();
        case 'format':
          if (filePath == null) return 'Error: file_path required for format.';
          return await analyzerService.format(filePath);
        case 'fix':
          if (filePath == null) return 'Error: file_path required for fix.';
          return await analyzerService.applyDetailedFixes(filePath);
        default:
          return 'Error: Unsupported analyzer command. Use "get_errors", "format", or "fix".';
      }
    } catch (e) {
      return 'Analyzer operation failed: $e';
    }
  }
}
