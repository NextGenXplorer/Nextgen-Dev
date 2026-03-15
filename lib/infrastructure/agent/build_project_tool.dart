import 'dart:convert';
import 'dart:io';
import '../storage/workspace_manager.dart';
import '../../domain/models/project.dart';
import 'agent_tool.dart';

class BuildProjectTool implements AgentTool {
  final WorkspaceManager _workspaceManager;
  BuildProjectTool(this._workspaceManager);

  @override
  String get name => 'build_project';
  @override
  String get displayName => 'Build Project';
  @override
  String get uiIcon => 'build_circle_outlined';
  @override
  String get description =>
      'Generates and saves a complete project codebase to local storage.';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final name = params['name'] as String? ?? 'Unnamed Project';
    final description = params['description'] as String? ?? '';
    final files = params['files'] as List<dynamic>? ?? [];
    final id = params['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
    final inputTasks = params['tasks'] as List<dynamic>? ?? [];

    try {
      final projectDirPath = await _workspaceManager.resolvePath(id);
      final projectsDir = Directory(projectDirPath);

      if (!await projectsDir.exists()) {
        await projectsDir.create(recursive: true);
      }

      // Load existing metadata if it exists
      Project? existingProject;
      final metaFile = File('${projectsDir.path}/metadata.json');
      if (await metaFile.exists()) {
        try {
          final json = jsonDecode(await metaFile.readAsString());
          existingProject = Project.fromJson(json);
        } catch (_) {}
      }

      List<String> savedPaths = existingProject?.filePaths.toList() ?? [];

      for (var file in files) {
        if (file is! Map) continue;
        final path = file['path'] as String? ?? 'unknown.txt';
        final content = file['content'] as String? ?? '';

        final localFile = File('${projectsDir.path}/$path');
        await localFile.parent.create(recursive: true);
        await localFile.writeAsString(content);
        if (!savedPaths.contains(path)) {
          savedPaths.add(path);
        }
      }

      // Handle tasks
      List<ProjectTask> tasks = existingProject?.tasks.toList() ?? [];
      for (var t in inputTasks) {
        if (t is! Map) continue;
        final tId = t['id'] as String? ?? (tasks.length + 1).toString();
        final tTitle = t['title'] as String? ?? '';
        final tStatus = t['status'] as String? ?? 'todo';

        final existingIdx = tasks.indexWhere((task) => task.id == tId || task.title == tTitle);
        if (existingIdx != -1) {
          tasks[existingIdx] = ProjectTask(
            id: tId,
            title: tTitle,
            status: TaskStatus.values.firstWhere((e) => e.name == tStatus, orElse: () => TaskStatus.todo),
          );
        } else {
          tasks.add(ProjectTask(
            id: tId,
            title: tTitle,
            status: TaskStatus.values.firstWhere((e) => e.name == tStatus, orElse: () => TaskStatus.todo),
          ));
        }
      }

      // Save project metadata
      final project = Project(
        id: id,
        name: existingProject?.name ?? name,
        description: existingProject?.description ?? description,
        createdAt: existingProject?.createdAt ?? DateTime.now(),
        filePaths: savedPaths,
        tasks: tasks,
      );

      await metaFile.writeAsString(jsonEncode(project.toJson()));

      return 'SUCCESS: Updated project "$name" ($id). Files: ${savedPaths.length}. Tasks: ${tasks.where((t) => t.status == TaskStatus.done).length}/${tasks.length} done. Path: ${projectsDir.path}';
    } catch (e) {
      return 'Error building project: $e';
    }
  }
}
