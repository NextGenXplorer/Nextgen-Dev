import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/project.dart';

final projectServiceProvider = Provider((ref) => ProjectService());

final projectListProvider = FutureProvider<List<Project>>((ref) {
  return ref.read(projectServiceProvider).listProjects();
});

class ProjectService {
  Future<Directory> _getProjectsDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/Projects');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<Project>> listProjects() async {
    final dir = await _getProjectsDir();
    final List<Project> projects = [];
    
    try {
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
      // Sort by newest first
      projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('Error listing projects: $e');
    }
    
    return projects;
  }

  Future<String> readFile(String projectId, String relativePath) async {
    final docDir = await getApplicationDocumentsDirectory();
    final file = File('${docDir.path}/Projects/$projectId/$relativePath');
    if (await file.exists()) {
      return await file.readAsString();
    }
    throw Exception('File not found: $relativePath');
  }

  Future<void> deleteProject(String id) async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/Projects/$id');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
