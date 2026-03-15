import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/workspace_manager.dart';
import '../../domain/models/project.dart';
import '../../domain/models/agent_event.dart';
import '../../application/agent_bus.dart';
import '../../application/providers/storage_providers.dart';

final projectServiceProvider = ChangeNotifierProvider((ref) {
  final manager = ref.watch(workspaceManagerProvider);
  final agentBus = ref.watch(agentBusProvider);
  return ProjectService(manager, agentBus);
});

final projectListProvider = FutureProvider<List<Project>>((ref) {
  final service = ref.watch(projectServiceProvider);
  return service.listProjects();
});

class ProjectService extends ChangeNotifier {
  final WorkspaceManager _workspaceManager;
  final AgentBus _agentBus;

  ProjectService(this._workspaceManager, this._agentBus) {
    _agentBus.eventStream.listen((event) {
      if (event.type == AgentEventType.fileRefreshRequested) {
        notifyListeners();
      }
    });
  }

  Future<List<Project>> listProjects() async {
    final List<Project> projects = [];
    try {
      final rootPath = await _workspaceManager.getWorkspaceRootPath();
      final dir = Directory(rootPath);
      
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        return [];
      }

      final List<FileSystemEntity> entities = await dir.list().toList();
      for (var entity in entities) {
        if (entity is Directory) {
          final metaFile = File('${entity.path}/metadata.json');
          if (await metaFile.exists()) {
            final json = jsonDecode(await metaFile.readAsString());
            projects.add(Project.fromJson(json));
          }
        }
      }
      projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('Error listing projects: $e');
    }
    return projects;
  }

  Future<String> readFile(String projectId, String relativePath) async {
    final absolutePath = await _workspaceManager.resolvePath(relativePath, projectId: projectId);
    final file = File(absolutePath);
    if (await file.exists()) {
      return await file.readAsString();
    }
    throw Exception('File not found: $relativePath at ${file.path}');
  }

  Future<void> deleteProject(String id) async {
    try {
      final projectPath = await _workspaceManager.resolvePath(id);
      final dir = Directory(projectPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error deleting project: $e');
    }
  }
}
