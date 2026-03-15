import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'agent_tool.dart';

class ListProjectsTool implements AgentTool {
  @override
  String get name => 'list_projects';

  @override
  String get displayName => 'List Projects';

  @override
  String get uiIcon => 'folder';

  @override
  String get description =>
      'List all existing projects in local storage and their basic metadata (ID, name, description). Useful to see what codebases exist before fetching their full context.';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final projectsDir = Directory(p.join(docDir.path, 'Projects'));

      if (!await projectsDir.exists()) {
        return 'No projects found (Projects directory does not exist).';
      }

      final List<Map<String, dynamic>> projectsList = [];

      final entities = projectsDir.listSync();
      for (final entity in entities) {
        if (entity is Directory) {
          final metadataFile = File(p.join(entity.path, 'metadata.json'));
          if (await metadataFile.exists()) {
            try {
              final content = await metadataFile.readAsString();
              final json = jsonDecode(content) as Map<String, dynamic>;
              projectsList.add({
                'id': json['id'],
                'name': json['name'],
                'description': json['description'],
                'path': entity.path,
              });
            } catch (e) {
              // Ignore projects with malformed metadata
            }
          }
        }
      }

      if (projectsList.isEmpty) {
        return 'No projects found in storage.';
      }

      final sb = StringBuffer();
      sb.writeln('Found ${projectsList.length} project(s):');
      for (var proj in projectsList) {
        sb.writeln(
          '- Project ID: ${proj['id']} | Name: "${proj['name']}" | Desc: "${proj['description']}"',
        );
      }

      return sb.toString();
    } catch (e) {
      return 'Failed to list projects: \$e';
    }
  }
}
