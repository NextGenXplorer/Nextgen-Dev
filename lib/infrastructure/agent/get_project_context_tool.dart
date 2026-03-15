import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'agent_tool.dart';
import '../../domain/models/project.dart';

class GetProjectContextTool implements AgentTool {
  @override
  String get name => 'get_project_context';

  @override
  String get displayName => 'Get Project Context';

  @override
  String get uiIcon => 'folder_open';

  @override
  String get description =>
      'Fetch the complete codebase structure, file paths, and current tasks for a specific Project ID. Always use `list_projects` first to get the correct project ID. '
      'Returns a comprehensive JSON string of the project layout.';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final projectId = params['project_id'];
    if (projectId == null || projectId is! String || projectId.isEmpty) {
      return 'Error: project_id parameter is required.';
    }

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final projectDir = Directory(p.join(docDir.path, 'Projects', projectId));

      if (!await projectDir.exists()) {
        return 'Error: Project folder for ID $projectId does not exist.';
      }

      final metadataFile = File(p.join(projectDir.path, 'metadata.json'));
      if (!await metadataFile.exists()) {
        return 'Error: metadata.json missing. This project might be corrupted.';
      }

      final metadataContent = await metadataFile.readAsString();
      final project = Project.fromJson(jsonDecode(metadataContent));

      // Attempt to build a quick tree layout of the actual directory.
      // E.g., ignoring build/ and .dart_tool/
      final treeSb = StringBuffer();
      int fileCount = 0;
      int lineCountTotal = 0;

      void scanDir(Directory currentDir, String prefix) {
        final entities = currentDir.listSync()
          ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
        for (var i = 0; i < entities.length; i++) {
          final entity = entities[i];
          final isLast = i == entities.length - 1;
          final name = p.basename(entity.path);

          // Skip common noisy folders
          if (name == 'build' ||
              name == '.dart_tool' ||
              name == '.git' ||
              name == 'linux' ||
              name == 'windows' ||
              name == 'macos' ||
              name == 'web') {
            continue;
          }

          treeSb.writeln('\$prefix\${isLast ? "└── " : "├── "}\$name');

          if (entity is Directory) {
            scanDir(entity, prefix + (isLast ? "    " : "│   "));
          } else if (entity is File) {
            fileCount++;
            // Don't actually count lines for big scans, too slow. Just count files.
          }
        }
      }

      treeSb.writeln(project.name);
      scanDir(projectDir, "");

      return '''
# Project Context: ${project.name}
ID: ${project.id}
Description: ${project.description}
Created: ${project.createdAt}

## Project Status:
Tasks:
${project.tasks.map((t) => "- [${t.status == TaskStatus.done ? 'x' : ' '}] ${t.title}").join('\n')}

## Codebase Structure ($fileCount files):
Abs Path: ${projectDir.path}

```text
${treeSb.toString()}
```

*Hint:* Use `read_file` with the absolute path obtained by prepending "${projectDir.path}\\" to the file you want to read.
''';
    } catch (e) {
      return 'Failed to load project context for ID $projectId: \$e';
    }
  }
}
