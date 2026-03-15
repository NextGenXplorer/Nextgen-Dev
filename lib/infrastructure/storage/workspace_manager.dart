import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Manages the structured local workspace so projects are accessible
/// by the user via file manager apps.
///
/// Storage hierarchy on device:
///   <Internal Storage>/NXG agent/projects/<project-name>/
class WorkspaceManager {
  static const String _agentFolder = 'NXG agent';
  static const String _projectsFolder = 'projects';

  String? _cachedWorkspaceRoot;

  /// Requests the necessary storage permissions and initializes the root folder.
  Future<bool> initializeWorkspace() async {
    if (!await _requestStoragePermission()) {
      debugPrint('Storage permission denied. Fallback to app directory.');
    }
    try {
      final rootPath = await getWorkspaceRootPath();
      final dir = Directory(rootPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        debugPrint('Created NXG workspace at: $rootPath');
      } else {
        debugPrint('Found existing NXG workspace at: $rootPath');
      }
      return true;
    } catch (e) {
      debugPrint('Failed to initialize workspace: $e');
      return false;
    }
  }

  /// Returns absolute path to `<Internal Storage>/NXG agent/projects/`.
  Future<String> getWorkspaceRootPath() async {
    if (_cachedWorkspaceRoot != null) return _cachedWorkspaceRoot!;

    Directory? baseDir;
    if (Platform.isAndroid) {
      baseDir = await getExternalStorageDirectory();
      baseDir ??= await getApplicationDocumentsDirectory();
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    // Walk up to the real public storage root on Android
    // External storage paths look like: /storage/emulated/0/Android/data/...
    // We walk up to /storage/emulated/0/ for file-manager visibility.
    String basePath = baseDir.path;
    if (Platform.isAndroid) {
      final segments = basePath.split('/');
      final androidIdx = segments.indexOf('Android');
      if (androidIdx > 0) {
        basePath = segments.sublist(0, androidIdx).join('/');
      }
    }

    final path = '$basePath/$_agentFolder/$_projectsFolder';
    _cachedWorkspaceRoot = path;
    return path;
  }

  /// Returns the absolute path to a specific project directory (creates if absent).
  Future<String> getProjectPath(String projectName) async {
    final safeName = _sanitize(projectName);
    final root = await getWorkspaceRootPath();
    final projectPath = '$root/$safeName';
    await Directory(projectPath).create(recursive: true);
    return projectPath;
  }

  /// Alias kept for agent tool compatibility.
  Future<String> createProjectFolder(String projectName) => getProjectPath(projectName);

  /// Resolves a relative path inside the workspace (optionally scoped to a project).
  Future<String> resolvePath(String path, {String? projectId}) async {
    final root = await getWorkspaceRootPath();
    if (projectId != null) return '$root/$projectId/$path';
    return '$root/$path';
  }

  String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '_').trim().replaceAll(' ', '_');

  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    if (await Permission.manageExternalStorage.request().isGranted) return true;
    final status = await Permission.storage.request();
    return status.isGranted;
  }
}
